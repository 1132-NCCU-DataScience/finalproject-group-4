import os
import csv
import re

# Set your folder path here
folder_path = './time_series_data_1/time_series_data_1'

# List all txt files in the folder
txt_files = [f for f in os.listdir(folder_path) if f.endswith('.txt')]

# Define the headers
headers = ['time', 'acc_x', 'acc_y', 'acc_z', 'time', 'gyro_x', 'gyro_y', 'gyro_z']

for txt_file in txt_files:
    txt_path = os.path.join(folder_path, txt_file)
    csv_file = txt_file.replace('.txt', '.csv')
    csv_path = os.path.join(folder_path, csv_file)
    

    with open(txt_path, 'r') as infile, open(csv_path, 'w', newline='') as outfile:
        writer = csv.writer(outfile)
        writer.writerow(headers)
        for line in infile:
            # Replace multiple spaces (2 or more) with a comma
            line = re.sub(r'\s{2,}', ',', line)
            # Split on comma
            values = [v.strip() for v in line.strip().split(',') if v.strip() != '']
            writer.writerow(values)