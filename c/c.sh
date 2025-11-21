#!/bin/bash

### -----------------------------
### CONFIGURATION
### -----------------------------
PROJECT_ID="qwiklabs-gcp-02-bb95c7e8a093"
REGION="us-central1"
ZONE="us-central1-b"
IMAGE_URI="gcr.io/$PROJECT_ID/horse-human:hypertune"
JOB_ID="horses-human-hypertune-$(date +%s)"

gcloud config set project $PROJECT_ID


### -----------------------------
### 1. CREATE WORKBENCH INSTANCE
### -----------------------------
echo "Creating Vertex AI Workbench instance..."
gcloud workbench instances create lab-workbench \
    --location=$REGION \
    --machine-type=n1-standard-4 \
    --disk-size-gb=100 \
    --boot-disk-type=pd-ssd \
    --zone=$ZONE

echo "Workbench instance creation triggered."
echo "NOTE: Workbench takes several minutes to be fully ready."


### -----------------------------
### 2. SETUP TRAINING DIRECTORY
### -----------------------------
echo "Creating project folders..."

mkdir -p horses_or_humans/trainer
cd horses_or_humans


### -----------------------------
### 3. CREATE DOCKERFILE
### -----------------------------
cat <<'EOF' > Dockerfile
FROM gcr.io/deeplearning-platform-release/tf2-gpu.2-9

WORKDIR /

RUN pip install cloudml-hypertune

COPY trainer /trainer

ENTRYPOINT ["python", "-m", "trainer.task"]
EOF


### -----------------------------
### 4. CREATE TRAINING SCRIPT
### -----------------------------
cat <<'EOF' > trainer/task.py
import tensorflow as tf
import tensorflow_datasets as tfds
import argparse
import hypertune

NUM_EPOCHS = 10

def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--learning_rate', required=True, type=float)
    parser.add_argument('--momentum', required=True, type=float)
    parser.add_argument('--num_neurons', required=True, type=int)
    return parser.parse_args()

def preprocess_data(image, label):
    image = tf.image.resize(image, (150,150))
    return tf.cast(image, tf.float32) / 255., label

def create_dataset():
    data, info = tfds.load(name='horses_or_humans', as_supervised=True, with_info=True)
    train_data = data['train'].map(preprocess_data).shuffle(1000).batch(64)
    val_data = data['test'].map(preprocess_data).batch(64)
    return train_data, val_data

def create_model(num_neurons, learning_rate, momentum):
    inputs = tf.keras.Input(shape=(150, 150, 3))
    x = tf.keras.layers.Conv2D(16, (3, 3), activation='relu')(inputs)
    x = tf.keras.layers.MaxPooling2D((2, 2))(x)
    x = tf.keras.layers.Conv2D(32, (3, 3), activation='relu')(x)
    x = tf.keras.layers.MaxPooling2D((2, 2))(x)
    x = tf.keras.layers.Conv2D(64, (3, 3), activation='relu')(x)
    x = tf.keras.layers.MaxPooling2D((2, 2))(x)
    x = tf.keras.layers.Flatten()(x)
    x = tf.keras.layers.Dense(num_neurons, activation='relu')(x)
    outputs = tf.keras.layers.Dense(1, activation='sigmoid')(x)
    model = tf.keras.Model(inputs, outputs)
    model.compile(
        loss='binary_crossentropy',
        optimizer=tf.keras.optimizers.SGD(learning_rate=learning_rate, momentum=momentum),
        metrics=['accuracy'])
    return model

def main():
    args = get_args()
    train_data, val_data = create_dataset()
    model = create_model(args.num_neurons, args.learning_rate, args.momentum)
    history = model.fit(train_data, epochs=NUM_EPOCHS, validation_data=val_data)
    hp_metric = history.history['val_accuracy'][-1]

    hpt = hypertune.HyperTune()
    hpt.report_hyperparameter_tuning_metric(
        hyperparameter_metric_tag='accuracy',
        metric_value=hp_metric,
        global_step=NUM_EPOCHS)

if __name__ == "__main__":
    main()
EOF


### -----------------------------
### 5. BUILD & PUSH DOCKER IMAGE
### -----------------------------
echo "Building Docker image..."
docker build -t $IMAGE_URI .

echo "Pushing to Container Registry..."
docker push $IMAGE_URI


### -----------------------------
### 6. RUN HYPERPARAMETER TUNING JOB
### -----------------------------
echo "Starting Vertex AI hyperparameter tuning job..."

gcloud ai hp-tuning-jobs create $JOB_ID \
  --region=$REGION \
  --display-name=$JOB_ID \
  --config=<(cat <<EOF
studySpec:
  metrics:
  - metricId: accuracy
    goal: MAXIMIZE
  parameters:
  - parameterId: learning_rate
    doubleValueSpec:
      minValue: 0.01
      maxValue: 1
    scaleType: LOG
  - parameterId: momentum
    doubleValueSpec:
      minValue: 0
      maxValue: 1
    scaleType: LINEAR
  - parameterId: num_neurons
    discreteValueSpec:
      values: [64,128,512]
trialJobSpec:
  workerPoolSpecs:
  - machineSpec:
      machineType: n1-standard-4
    replicaCount: 1
    containerSpec:
      imageUri: $IMAGE_URI
maxTrialCount: 15
parallelTrialCount: 3
EOF
)

echo "Hyperparameter tuning job started: $JOB_ID"
echo "You can track it in: Vertex AI → Training → Hyperparameter Tuning Jobs"
