# Databricks notebook source
# MAGIC %md
# MAGIC # Mat AI Active Learning ETL
# MAGIC
# MAGIC Notebook này xử lý dữ liệu ảnh confidence thấp được app Flutter gửi về backend local.
# MAGIC
# MAGIC Luồng:
# MAGIC
# MAGIC ```text
# MAGIC backend/dataset/raw/
# MAGIC backend/dataset/metadata/low_confidence_frames.jsonl
# MAGIC   -> Bronze metadata
# MAGIC   -> Silver manifest ảnh hợp lệ
# MAGIC   -> prelabels YOLO nháp
# MAGIC   -> export YOLO dataset sau khi review label
# MAGIC ```

# COMMAND ----------

# MAGIC %md
# MAGIC ## 0. Cấu hình đường dẫn
# MAGIC
# MAGIC Upload thư mục `backend/dataset` lên Databricks Volume sao cho cấu trúc trên Volume là:
# MAGIC
# MAGIC ```text
# MAGIC /Volumes/workspace/default/mat_ai_backend/dataset/
# MAGIC   raw/
# MAGIC   metadata/low_confidence_frames.jsonl
# MAGIC ```
# MAGIC
# MAGIC Nếu bạn dùng catalog/schema/volume khác, sửa `BASE_PATH`.

# COMMAND ----------

BASE_PATH = "/Volumes/workspace/default/mat_ai_backend"
DATASET_PATH = f"{BASE_PATH}/dataset"
METADATA_PATH = f"{DATASET_PATH}/metadata/low_confidence_frames.jsonl"
RAW_PATH = f"{DATASET_PATH}/raw"
PROCESSED_PATH = f"{DATASET_PATH}/processed"
PRELABEL_PATH = f"{DATASET_PATH}/prelabels"
REVIEWED_LABEL_PATH = f"{DATASET_PATH}/reviewed_labels"
YOLO_EXPORT_PATH = f"{DATASET_PATH}/yolo"

print("BASE_PATH:", BASE_PATH)
print("METADATA_PATH:", METADATA_PATH)

# COMMAND ----------

# MAGIC %md
# MAGIC ## 1. Đọc Bronze metadata

# COMMAND ----------

from pyspark.sql.functions import col, explode, size

bronze_df = spark.read.json(METADATA_PATH)

display(bronze_df.limit(10))
print("Bronze rows:", bronze_df.count())

# COMMAND ----------

# MAGIC %md
# MAGIC ## 2. Validate ảnh tồn tại và tạo Silver manifest
# MAGIC
# MAGIC Metadata lưu `image_path` dạng `dataset/raw/...`, nên ảnh thật sẽ là:
# MAGIC
# MAGIC ```python
# MAGIC BASE_PATH + "/" + image_path
# MAGIC ```

# COMMAND ----------

from pyspark.sql.functions import concat, lit, regexp_replace

print("Volume root:")
display(dbutils.fs.ls(BASE_PATH))
print("Dataset root:")
display(dbutils.fs.ls(DATASET_PATH))
print("Raw root:")
display(dbutils.fs.ls(RAW_PATH))

image_files_df = (
    spark.read.format("binaryFile")
    .option("recursiveFileLookup", "true")
    .load(RAW_PATH)
    .select(col("path").alias("binary_image_uri"), col("length").alias("image_bytes"))
    .withColumn(
        "join_image_path",
        regexp_replace(
            regexp_replace(col("binary_image_uri"), "^dbfs:", ""),
            f"^{BASE_PATH}/",
            "",
        ),
    )
)

manifest_df = (
    bronze_df
    .withColumn("join_image_path", col("image_path"))
    .join(image_files_df, on="join_image_path", how="inner")
    .withColumn("absolute_image_uri", col("binary_image_uri"))
    .dropDuplicates(["image_path"])
    .filter(col("image_width") > 0)
    .filter(col("image_height") > 0)
    .filter(size(col("detections")) > 0)
)

print("Metadata sample paths:")
display(bronze_df.select("image_path").limit(10))
print("Image file sample paths:")
display(image_files_df.select("binary_image_uri", "join_image_path", "image_bytes").limit(10))

display(manifest_df.select(
    "image_path",
    "image_width",
    "image_height",
    "image_bytes",
    "user_id",
    "model_version",
    "status",
).limit(20))

print("Valid manifest rows:", manifest_df.count())

# COMMAND ----------

# MAGIC %md
# MAGIC ## 3. Ghi Silver manifest ra Delta/JSONL

# COMMAND ----------

silver_table = "default.mat_ai_low_confidence_manifest"

(
    manifest_df
    .write
    .mode("overwrite")
    .format("delta")
    .saveAsTable(silver_table)
)

manifest_json_path = f"{PROCESSED_PATH}/manifest_json"
(
    manifest_df
    .coalesce(1)
    .write
    .mode("overwrite")
    .json(manifest_json_path)
)

print("Saved table:", silver_table)
print("Saved JSON manifest:", manifest_json_path)

# COMMAND ----------

# MAGIC %md
# MAGIC ## 4. Phân tích nhanh detection confidence thấp

# COMMAND ----------

from pyspark.sql.functions import avg, count, min as spark_min, max as spark_max

detection_df = (
    manifest_df
    .select("image_path", "image_width", "image_height", explode("detections").alias("detection"))
    .select(
        "image_path",
        "image_width",
        "image_height",
        col("detection.tag").alias("tag"),
        col("detection.confidence").alias("confidence"),
        col("detection.box").alias("box"),
    )
)

display(
    detection_df
    .groupBy("tag")
    .agg(
        count("*").alias("count"),
        avg("confidence").alias("avg_confidence"),
        spark_min("confidence").alias("min_confidence"),
        spark_max("confidence").alias("max_confidence"),
    )
    .orderBy(col("count").desc())
)

# COMMAND ----------

# MAGIC %md
# MAGIC ## 5. Tạo prelabels YOLO nháp
# MAGIC
# MAGIC Đây là nhãn nháp từ model đang nghi ngờ. Dùng để mở trong tool label cho nhanh, không nên train thật khi chưa review.

# COMMAND ----------

import json
import os
from pathlib import Path

COCO_CLASSES = [
    "person", "bicycle", "car", "motorcycle", "airplane", "bus", "train", "truck", "boat",
    "traffic light", "fire hydrant", "stop sign", "parking meter", "bench", "bird", "cat",
    "dog", "horse", "sheep", "cow", "elephant", "bear", "zebra", "giraffe", "backpack",
    "umbrella", "handbag", "tie", "suitcase", "frisbee", "skis", "snowboard", "sports ball",
    "kite", "baseball bat", "baseball glove", "skateboard", "surfboard", "tennis racket",
    "bottle", "wine glass", "cup", "fork", "knife", "spoon", "bowl", "banana", "apple",
    "sandwich", "orange", "broccoli", "carrot", "hot dog", "pizza", "donut", "cake",
    "chair", "couch", "potted plant", "bed", "dining table", "toilet", "tv", "laptop",
    "mouse", "remote", "keyboard", "cell phone", "microwave", "oven", "toaster", "sink",
    "refrigerator", "book", "clock", "vase", "scissors", "teddy bear", "hair drier",
    "toothbrush",
]
CLASS_TO_ID = {name: idx for idx, name in enumerate(COCO_CLASSES)}


def clamp01(value: float) -> float:
    return max(0.0, min(1.0, float(value)))


def to_yolo_box(box, image_width: int, image_height: int):
    if box is None or len(box) < 4 or image_width <= 0 or image_height <= 0:
        return None

    x1, y1, x2, y2 = [float(v) for v in box[:4]]

    # flutter_vision đôi khi trả tọa độ normalized nhưng có thể vượt 1 nhẹ.
    # Nếu giá trị nhỏ hơn 2, coi như normalized rồi clamp về [0, 1].
    if x2 <= 2.0 and y2 <= 2.0:
        x1, y1, x2, y2 = [clamp01(v) for v in [x1, y1, x2, y2]]
    else:
        x1 = clamp01(x1 / image_width)
        x2 = clamp01(x2 / image_width)
        y1 = clamp01(y1 / image_height)
        y2 = clamp01(y2 / image_height)

    if x2 <= x1 or y2 <= y1:
        return None

    x_center = (x1 + x2) / 2
    y_center = (y1 + y2) / 2
    width = x2 - x1
    height = y2 - y1
    return x_center, y_center, width, height


dbutils.fs.mkdirs(PRELABEL_PATH)

rows = manifest_df.select(
    "image_path",
    "image_width",
    "image_height",
    "detections",
).collect()

written = 0
for row in rows:
    image_stem = Path(row["image_path"]).stem
    label_lines = []

    for detection in row["detections"]:
        tag = detection["tag"]
        if tag not in CLASS_TO_ID:
            continue

        yolo_box = to_yolo_box(detection["box"], row["image_width"], row["image_height"])
        if yolo_box is None:
            continue

        x_center, y_center, width, height = yolo_box
        label_lines.append(
            f"{CLASS_TO_ID[tag]} {x_center:.6f} {y_center:.6f} {width:.6f} {height:.6f}"
        )

    if label_lines:
        dbutils.fs.put(
            f"{PRELABEL_PATH}/{image_stem}.txt",
            "\n".join(label_lines) + "\n",
            overwrite=True,
        )
        written += 1

print(f"Wrote {written} YOLO prelabel files to {PRELABEL_PATH}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 6. Review label
# MAGIC
# MAGIC Tải ảnh + prelabels xuống CVAT/Label Studio/Roboflow để sửa nhãn.
# MAGIC
# MAGIC Sau khi sửa xong, upload label YOLO đã duyệt vào:
# MAGIC
# MAGIC ```text
# MAGIC /Volumes/workspace/default/mat_ai_backend/dataset/reviewed_labels/
# MAGIC ```
# MAGIC
# MAGIC Tên file phải trùng stem ảnh:
# MAGIC
# MAGIC ```text
# MAGIC raw/user/image_123.jpg
# MAGIC reviewed_labels/image_123.txt
# MAGIC ```

# COMMAND ----------

# MAGIC %md
# MAGIC ## 7. Export YOLO dataset từ reviewed labels
# MAGIC
# MAGIC Nếu muốn test nhanh bằng prelabels, đặt:
# MAGIC
# MAGIC ```python
# MAGIC USE_PRELABELS = True
# MAGIC ```

# COMMAND ----------

import random

USE_PRELABELS = True
VAL_RATIO = 0.2
SEED = 42

source_label_path = PRELABEL_PATH if USE_PRELABELS else REVIEWED_LABEL_PATH
dbutils.fs.mkdirs(source_label_path)

label_files = {
    Path(file.path).stem: file.path
    for file in dbutils.fs.ls(source_label_path)
    if file.path.endswith(".txt")
}

eligible = []
for row in manifest_df.select("image_path", "absolute_image_uri").collect():
    image_stem = Path(row["image_path"]).stem
    if image_stem in label_files:
        eligible.append((row["absolute_image_uri"], label_files[image_stem], image_stem))

random.Random(SEED).shuffle(eligible)
val_count = round(len(eligible) * VAL_RATIO)

dbutils.fs.rm(YOLO_EXPORT_PATH, recurse=True)
for split in ["train", "val"]:
    dbutils.fs.mkdirs(f"{YOLO_EXPORT_PATH}/images/{split}")
    dbutils.fs.mkdirs(f"{YOLO_EXPORT_PATH}/labels/{split}")

for index, (image_uri, label_uri, image_stem) in enumerate(eligible):
    split = "val" if index < val_count else "train"
    image_name = Path(image_uri).name
    dbutils.fs.cp(image_uri, f"{YOLO_EXPORT_PATH}/images/{split}/{image_name}")
    dbutils.fs.cp(label_uri, f"{YOLO_EXPORT_PATH}/labels/{split}/{image_stem}.txt")

names = ", ".join([f'"{name}"' for name in COCO_CLASSES])
data_yaml = "\n".join([
    f"path: {YOLO_EXPORT_PATH}",
    "train: images/train",
    "val: images/val",
    f"nc: {len(COCO_CLASSES)}",
    f"names: [{names}]",
    "",
])
dbutils.fs.put(f"{YOLO_EXPORT_PATH}/data.yaml", data_yaml, overwrite=True)

print(f"Exported {len(eligible)} images to {YOLO_EXPORT_PATH}")
print(f"Train: {len(eligible) - val_count}, Val: {val_count}")
print(f"Labels source: {source_label_path}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 8. Train sau ETL
# MAGIC
# MAGIC Nếu cluster Databricks đủ RAM/GPU:
# MAGIC
# MAGIC ```python
# MAGIC %pip install ultralytics
# MAGIC from ultralytics import YOLO
# MAGIC model = YOLO("yolov8n.pt")
# MAGIC model.train(data=f"{YOLO_EXPORT_PATH}/data.yaml", epochs=50, imgsz=640, batch=8)
# MAGIC ```
# MAGIC
# MAGIC Nếu Databricks yếu, export `dataset/yolo` ra zip rồi train trên Google Colab.
