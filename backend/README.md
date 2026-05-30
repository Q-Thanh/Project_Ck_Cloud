# Mat AI Training Frame Collector

Backend nhỏ để nhận các frame có độ tin cậy thấp từ app Flutter và lưu thành dữ liệu thô cho bước gắn nhãn/train lại.

## Chạy local

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
```

Kiểm tra:

```bash
curl http://127.0.0.1:8000/health
```

## Đường dẫn từ Flutter

Trong Android emulator, Flutter dùng:

```dart
http://10.0.2.2:8000
```

Nếu chạy trên điện thoại thật, đổi `_trainingBackendUrl` trong `lib/main.dart` sang IP LAN của máy đang chạy backend, ví dụ:

```dart
http://192.168.1.10:8000
```

## Dữ liệu lưu ra

Ảnh:

```text
backend/dataset/raw/{user_id}/{user_id}_{timestamp}.jpg
```

Metadata:

```text
backend/dataset/metadata/low_confidence_frames.jsonl
```

## ETL dataset

Sau khi app đã thu được ảnh, chạy pipeline chuẩn bị dữ liệu:

```bash
python3 etl/run_pipeline.py
```

Pipeline sẽ tạo:

```text
backend/dataset/processed/manifest.jsonl
backend/dataset/prelabels/
```

`prelabels` chỉ là nhãn nháp lấy từ detection của model. Sau khi review/sửa nhãn, đặt nhãn YOLO cuối cùng vào:

```text
backend/dataset/reviewed_labels/
```

Sau đó export dataset YOLO:

```bash
python3 etl/03_export_yolo_dataset.py
```

Nếu chỉ muốn test nhanh bằng nhãn nháp:

```bash
python3 etl/03_export_yolo_dataset.py --use-prelabels
```
