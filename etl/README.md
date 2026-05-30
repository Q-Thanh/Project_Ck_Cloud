# Mat AI ETL Pipeline

Pipeline này biến dữ liệu thu từ app thành dataset có thể gắn nhãn và train YOLO.

## Luồng dữ liệu

```text
backend/dataset/raw/
backend/dataset/metadata/low_confidence_frames.jsonl
  -> etl/01_prepare_manifest.py
  -> etl/02_create_prelabels.py
  -> human review
  -> etl/03_export_yolo_dataset.py
  -> train YOLO / export TFLite
```

## 1. Tạo manifest sạch

```bash
python3 etl/01_prepare_manifest.py
```

Output:

```text
backend/dataset/processed/manifest.jsonl
```

## 2. Tạo nhãn nháp YOLO từ detection confidence thấp

```bash
python3 etl/02_create_prelabels.py
```

Output:

```text
backend/dataset/prelabels/{image_stem}.txt
```

Các file này chỉ là nhãn nháp. Không nên train trực tiếp nếu chưa review.

## 3. Review/gắn nhãn

Dùng CVAT, Label Studio, Roboflow hoặc tool bạn chọn để sửa nhãn. Sau khi review, đặt label YOLO cuối cùng vào:

```text
backend/dataset/reviewed_labels/{image_stem}.txt
```

## 4. Export dataset YOLO

```bash
python3 etl/03_export_yolo_dataset.py
```

Output:

```text
backend/dataset/yolo/
  images/train/
  images/val/
  labels/train/
  labels/val/
  data.yaml
```

Nếu muốn test nhanh bằng nhãn nháp, dùng:

```bash
python3 etl/03_export_yolo_dataset.py --use-prelabels
```

## 5. Train và export TFLite

```bash
yolo detect train model=yolov8n.pt data=backend/dataset/yolo/data.yaml epochs=50 imgsz=640
yolo export model=runs/detect/train/weights/best.pt format=tflite
```
