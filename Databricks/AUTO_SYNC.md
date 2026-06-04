# Auto Sync Local Dataset To Databricks

Mục tiêu mức 2:

```text
backend local thu ảnh
  -> script local đóng gói dataset
  -> upload zip lên Databricks Volume
  -> trigger Databricks Job ETL
```

## 1. Cài Databricks CLI

Trên Mac:

```bash
brew install databricks
```

Nếu không dùng Homebrew, xem cách cài CLI trong Databricks UI.

## 2. Cấu hình đăng nhập

Trong Databricks, tạo Personal Access Token:

```text
User Settings -> Developer -> Access tokens -> Generate new token
```

Sau đó trên Mac:

```bash
databricks configure
```

Nhập:

```text
Databricks host: https://<workspace-url>
Token: <token-vừa-tạo>
```

Test:

```bash
databricks current-user me
```

## 3. Tạo Databricks Job

Trong Databricks:

```text
Workflows -> Create job
```

Task:

```text
Type: Notebook
Notebook: active_learning_etl
```

Ghi lại `job_id` trong URL hoặc phần Job details.

## 4. Sync dataset và chạy Job

Chỉ upload zip:

```bash
python3 scripts/sync_dataset_to_databricks.py
```

Upload zip và trigger Job:

```bash
python3 scripts/sync_dataset_to_databricks.py --job-id <JOB_ID>
```

Mặc định script upload vào:

```text
/Volumes/workspace/default/mat_ai_backend/exports/mat_ai_backend_dataset.zip
```

Nếu volume khác:

```bash
python3 scripts/sync_dataset_to_databricks.py \
  --volume-dir /Volumes/workspace/default/mat_ai_backend/exports \
  --job-id <JOB_ID>
```

## 5. Tự động theo lịch trên Mac

Databricks Job chỉ tự chạy trên dữ liệu đã upload. Để tự upload từ Mac, dùng cron:

```bash
crontab -e
```

Ví dụ chạy mỗi ngày 23:00:

```cron
0 23 * * * cd /Users/thanh/Documents/DienToanDM/CKi/mat_ai_pro && /usr/bin/python3 scripts/sync_dataset_to_databricks.py --job-id <JOB_ID> >> exports/databricks_sync.log 2>&1
```

Điều kiện: máy Mac phải bật, có mạng, và backend đã có dữ liệu trong `backend/dataset`.
