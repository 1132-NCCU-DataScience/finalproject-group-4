import os
import glob
import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import mean_squared_error
import joblib

# 設定參數
DATA_PATH = '/Users/zhangyongxuan/Desktop/data_science_project/data/time_series_data/'          # 原始資料目錄
LABEL_FILE = '/Users/zhangyongxuan/Desktop/data_science_project/data/label/label_and_comments.xlsx'  # 評分標籤文件
MODEL_PATH = '/Users/zhangyongxuan/Desktop/data_science_project/model/rf_model.pkl'  # 模型儲存路徑
SAMPLE_RATE = 100               # 取樣頻率(Hz)

def load_and_process_data():
    """載入並處理所有受測者資料"""
    # 載入評分標籤
    labels_df = pd.read_excel(LABEL_FILE, index_col='受測者ID')
    
    all_features = []
    
    # 遍歷所有受測者資料檔
    for file_path in glob.glob(os.path.join(DATA_PATH, 'h*.txt')):
        # 解析受測者ID
        base_name = os.path.basename(file_path)
        subject_id = base_name.split('_')[0][1:]  # 提取h後的數字
        
        # 讀取原始資料
        df = pd.read_csv(file_path, header=None, delim_whitespace=True)
        df.columns = [
            'seq', 'vx', 'vy', 'vz', 
            'seq_omega', 'wx', 'wy', 'wz'
        ]
        
        # 特徵提取
        features = extract_swing_features(df)
        features['subject_id'] = int(subject_id)
        
        # 合併評分標籤
        features = features.merge(
            labels_df, 
            left_on='subject_id', 
            right_index=True
        )
        
        all_features.append(features)
    
    return pd.concat(all_features)

def extract_swing_features(df):
    """從原始數據提取揮拍特徵"""
    features = []
    
    # 按揮拍序號分組
    for seq, group in df.groupby('seq'):
        # 基本統計量
        v_norm = np.sqrt(group[['vx','vy','vz']].pow(2).sum(axis=1))
        w_norm = np.sqrt(group[['wx','wy','wz']].pow(2).sum(axis=1))
        
        # 時序特徵
        peak_v_idx = v_norm.idxmax()
        accel_phase = group.index[group.index <= peak_v_idx]
        decel_phase = group.index[group.index > peak_v_idx]
        
        # 特徵字典
        feat = {
            'swing_seq': seq,
            'max_v': v_norm.max(),
            'mean_v': v_norm.mean(),
            'max_w': w_norm.max(),
            'accel_time': len(accel_phase)/SAMPLE_RATE,
            'decel_time': len(decel_phase)/SAMPLE_RATE,
            'v_peak_time': peak_v_idx/SAMPLE_RATE,
            'w_integral': w_norm.sum()/SAMPLE_RATE
        }
        
        features.append(feat)
    
    return pd.DataFrame(features)

def train_model(data):
    """訓練評分模型"""
    # 分割特徵與標籤
    X = data[['max_v','mean_v','max_w','accel_time','decel_time','v_peak_time','w_integral']]
    y = data['Average_Score']
    
    # 資料標準化
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    
    # 分割訓練測試集
    X_train, X_test, y_train, y_test = train_test_split(
        X_scaled, y, test_size=0.2, random_state=42
    )
    
    # 建立模型
    model = RandomForestRegressor(
        n_estimators=200,
        max_depth=8,
        random_state=42
    )
    model.fit(X_train, y_train)
    
    # 評估模型
    y_pred = model.predict(X_test)
    rmse = np.sqrt(mean_squared_error(y_test, y_pred))
    print(f'Model RMSE: {rmse:.2f}')
    
    # 保存模型與標準化器
    joblib.dump(model, MODEL_PATH)
    joblib.dump(scaler, 'model/scaler.pkl')
    
    return model, scaler

def predict_new_swing(data, model, scaler):
    """預測新揮拍數據"""
    # 提取特徵
    features = extract_single_swing(data)
    
    # 標準化
    scaled_data = scaler.transform([features])
    
    # 預測
    score = model.predict(scaled_data)[0]
    return round(score, 2)

def extract_single_swing(raw_data):
    """從單筆揮拍數據提取特徵"""
    df = pd.DataFrame(
        [raw_data],
        columns=['vx','vy','vz','wx','wy','wz']
    )
    
    v_norm = np.sqrt(df[['vx','vy','vz']].pow(2).sum(axis=1))
    w_norm = np.sqrt(df[['wx','wy','wz']].pow(2).sum(axis=1))
    
    return {
        'max_v': v_norm.max(),
        'mean_v': v_norm.mean(),
        'max_w': w_norm.max(),
        'accel_time': 0.15,  # 根據實際數據調整
        'decel_time': 0.35,  # 根據實際數據調整
        'v_peak_time': 0.18, # 根據實際數據調整
        'w_integral': w_norm.sum()/SAMPLE_RATE
    }

# 主程式流程
if __name__ == "__main__":
    # 訓練模型
    print("正在載入資料與訓練模型...")
    full_data = load_and_process_data()
    model, scaler = train_model(full_data)
    
    # 範例預測
    test_data = [
        [-5.946, 1.15, 8.466, 0.378, 0.058, -1.066],  # 揮拍1
        [-5.726, 1.148, 8.408, 0.318, 0.004, -1.066], # 揮拍2
        # 可添加最多4組測試數據
    ]
    
    print("\n即時評測結果：")
    for i, data in enumerate(test_data, 1):
        score = predict_new_swing(data, model, scaler)
        print(f"揮拍{i}預測評分：{score}/5")
