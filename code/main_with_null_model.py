import os
import glob
import pandas as pd
import numpy as np
import joblib
from scipy.integrate import trapezoid
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import mean_squared_error
from sklearn.dummy import DummyRegressor
from pathlib import Path

# 設定參數
DATA_PATH = 'data/time_series_data_csv'
LABEL_FILE = 'data/label/label_and_comments.xlsx'
MODEL_DIR = 'results/model/'
SAMPLE_RATE = 203

# 建立目錄
Path(MODEL_DIR).mkdir(parents=True, exist_ok=True)

def load_and_process_data():
    """載入並處理所有受測者CSV資料"""
    # 讀取標籤文件
    labels_df = pd.read_excel(
        LABEL_FILE,
        index_col='Filename',
        usecols=[
            'Filename',
            'Swing Path Accuracy',
            'Swing Speed Smoothness',
            'Wrist Rotation Timing Accuracy',
            'Hit Timing Accuracy',
            'Ball Contact Position Accuracy'
        ]
    )
    all_features = []

    for csv_path in glob.glob(os.path.join(DATA_PATH, 'h*.csv')):
        try:
            base_name = os.path.basename(csv_path)
            subject_id = base_name.split('_')[0]

            # 檢查標籤是否存在
            if subject_id not in labels_df.index:
                print(f"Warning: {subject_id} has no corresponding label")
                continue

            # 讀取並處理CSV資料
            df = pd.read_csv(csv_path)
            required_columns = {'time', 'acc_x', 'acc_y', 'acc_z', 'gyro_x', 'gyro_y', 'gyro_z'}
            if not required_columns.issubset(df.columns):
                print(f"File {base_name} missing required columns, skipping")
                continue

            df = df.rename(columns={
                'time': 'timestamp',
                'acc_x': 'vx',
                'acc_y': 'vy',
                'acc_z': 'vz',
                'gyro_x': 'wx',
                'gyro_y': 'wy',
                'gyro_z': 'wz'
            })

            # 特徵提取
            features = extract_swing_features(df)
            if features.empty:
                continue

            features['subject_id'] = subject_id

            # 合併所有標籤數值
            label_data = labels_df.loc[subject_id]
            for col in label_data.index:
                features[col] = label_data[col]
            
            all_features.append(features)

        except Exception as e:
            print(f"Error processing {base_name}: {str(e)}")
    
    return pd.concat(all_features) if all_features else pd.DataFrame()

def extract_swing_features(df):
    """提取特徵"""
    features = []
    
    # 驗證資料
    if df.empty or 'timestamp' not in df.columns:
        return pd.DataFrame()
    
    try:
        # 計算合成量
        df['v_norm'] = np.linalg.norm(df[['vx','vy','vz']], axis=1)
        df['w_norm'] = np.linalg.norm(df[['wx','wy','wz']], axis=1)
    except KeyError as e:
        print(f"Missing sensor data columns: {str(e)}")
        return pd.DataFrame()
    
    # 檢測揮拍分段
    try:
        time_diff = df['timestamp'].diff().fillna(0)
        swing_groups = (time_diff > 50).cumsum()
    except Exception as e:
        print(f"Timestamp processing error: {str(e)}")
        return pd.DataFrame()

    for swing_id, group in df.groupby(swing_groups):
        # 揮拍有效性檢查
        if len(group) < 10 or group['v_norm'].max() < 1e-6:
            continue
            
        try:
            # 時間處理
            time_sec = (group['timestamp'] - group['timestamp'].iloc[0]) / 1000.0
            peak_idx = group['v_norm'].idxmax()
            
            # 特徵計算
            if peak_idx >= len(time_sec):
                continue

            feat = {
                'swing_id': swing_id,
                'max_v': group['v_norm'].max(),
                'mean_v': group['v_norm'].mean(),
                'max_w': group['w_norm'].max(),
                'accel_time': time_sec.iloc[peak_idx],
                'decel_time': time_sec.iloc[-1] - time_sec.iloc[peak_idx],
                'v_peak_time': time_sec.iloc[peak_idx],
                'w_integral': trapezoid(group['w_norm'], time_sec)
            }
            features.append(feat)
        except Exception as e:
            print(f"Error extracting features for swing {swing_id}: {str(e)}")
    
    return pd.DataFrame(features) if features else pd.DataFrame()

def train_model(data):
    """訓練多目標評分模型"""
    if data.empty:
        raise ValueError("No valid training data")
    
    # 定義特徵與多個目標
    feature_cols = ['max_v','mean_v','max_w','accel_time','decel_time','v_peak_time','w_integral']
    target_cols = [
        'Swing Path Accuracy',
        'Swing Speed Smoothness',
        'Wrist Rotation Timing Accuracy',
        'Hit Timing Accuracy',
        'Ball Contact Position Accuracy'
    ]
    
    X = data[feature_cols]
    y = data[target_cols]

    # 資料標準化
    scaler = StandardScaler()
    X_scaled = pd.DataFrame(
        scaler.fit_transform(X),
        columns=X.columns
    )
    
    # 分割資料集
    X_train, X_test, y_train, y_test = train_test_split(
        X_scaled, 
        y, 
        test_size=0.2, 
        random_state=42
    )

    # Null model (DummyRegressor)
    null_model = DummyRegressor(strategy="mean")
    null_model.fit(X_train, y_train)
    y_null_pred = null_model.predict(X_test)
    print("Null Model RMSE per target: ")
    for i, col in enumerate(target_cols):
        rmse = np.sqrt(mean_squared_error(y_test.iloc[:, i], y_null_pred[:, i]))
        print(f"- {col}:{rmse:.2f}")
        
    
    # 輸出模型
    model = RandomForestRegressor(
        n_estimators=200,
        max_depth=8,
        random_state=42,
        n_jobs=-1
    )
    model.fit(X_train, y_train)
    
    # 模型評估（計算RMSE）
    y_pred = model.predict(X_test)
    print('Model RMSE per target:')
    for i, col in enumerate(target_cols):
        rmse = np.sqrt(mean_squared_error(y_test.iloc[:, i], y_pred[:, i]))
        print(f"- {col}: {rmse:.2f}")
    
    # 保存模型
    
    return model, scaler

def predict_new_swing(raw_data, model, scaler):
    """多目標評測"""
    try:
        features = extract_single_swing(raw_data)
        features_df = pd.DataFrame([features], columns=scaler.feature_names_in_)
        scaled_data = scaler.transform(features_df)
        predictions = model.predict(scaled_data)[0]
        
        # 預測結果
        return {
            'Swing Path Accuracy': max(0.0, min(5.0, round(predictions[0], 2))),
            'Swing Speed Smoothness': max(0.0, min(5.0, round(predictions[1], 2))),
            'Wrist Rotation Timing Accuracy': max(0.0, min(5.0, round(predictions[2], 2))),
            'Hit Timing Accuracy': max(0.0, min(5.0, round(predictions[3], 2))),
            'Ball Contact Position Accuracy': max(0.0, min(5.0, round(predictions[4], 2)))
        }
    except Exception as e:
        print(f"Prediction failed: {str(e)}")
        return {
            'Swing Path Accuracy': 0.0,
            'Swing Speed Smoothness': 0.0,
            'Wrist Rotation Timing Accuracy': 0.0,
            'Hit Timing Accuracy': 0.0,
            'Ball Contact Position Accuracy': 0.0
        }

def extract_single_swing(raw_data):
    """單筆揮拍特徵提取"""
    try:
        if len(raw_data) != 6:
            raise ValueError("需要6項數值（xyz速度以及xyz角速度）")
            
        vx, vy, vz, wx, wy, wz = map(float, raw_data)
        
        v_norm = np.sqrt(vx**2 + vy**2 + vz**2)
        w_norm = np.sqrt(wx**2 + wy**2 + wz**2)
        
        return {
            'max_v': v_norm,
            'mean_v': v_norm,
            'max_w': w_norm,
            'accel_time': 0.15,
            'decel_time': 0.35,
            'v_peak_time': 0.18,
            'w_integral': w_norm * 0.01
        }
    except Exception as e:
        print(f"輸入資料錯誤: {str(e)}")
        return {key: 0.0 for key in [
            'max_v', 'mean_v', 'max_w',
            'accel_time', 'decel_time',
            'v_peak_time', 'w_integral'
        ]}

if __name__ == "__main__":
    try:
        print("=== Badminton Swing Analysis System ===")
        print("Loading data...")
        full_data = load_and_process_data()
        
        if not full_data.empty:
            print(f"Loaded {len(full_data)} swings")
            print("Training model...")
            model, scaler = train_model(full_data)
            
            # 輸入測試資料
            test_swings = [
                [-5.946, 1.15, 8.466, 0.378, 0.058, -1.066],
                [-5.726, 1.148, 8.408, 0.318, 0.004, -1.066]
            ]
            
            print("\nReal-time Evaluation:")
            for i, swing in enumerate(test_swings, 1):
                result = predict_new_swing(swing, model, scaler)
                print(f"Swing {i} Results:")
                for k, v in result.items():
                    print(f"- {k}: {v}/5")
        else:
            print("Error: No valid data loaded")
            
    except Exception as e:
        print(f"System Error: {str(e)}")