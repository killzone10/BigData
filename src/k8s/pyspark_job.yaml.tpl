# # Copyright 2018 Google LLC
  #
  # Licensed under the Apache License, Version 2.0 (the "License");
  # you may not use this file except in compliance with the License.
  # You may obtain a copy of the License at
  #
  #     https://www.apache.org/licenses/LICENSE-2.0
  #
  # Unless required by applicable law or agreed to in writing, software
  # distributed under the License is distributed on an "AS IS" BASIS,
  # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  # See the License for the specific language governing permissions and
  # limitations under the License.
  #
  # Support for Python is experimental, and requires building SNAPSHOT image of Apache Spark,
  # with `imagePullPolicy` set to Always

  apiVersion: "sparkoperator.k8s.io/v1beta2"
  kind: SparkApplication
  metadata:
    name: gcs-reader
    namespace: default
  spec:
    type: Python
    pythonVersion: "3"
    mode: cluster
    image: "docker.io/biodatageeks/spark-py:pysequila-0.3.3-gke-272379a"
    imagePullPolicy: Always
    mainApplicationFile: gs://${staging_bucket}/src/pyspark_k8s_job.py
    sparkVersion: "3.1.1"
    sparkConf:
      spark.kubernetes.executor.deleteOnTermination: "true"
    restartPolicy:
      type: OnFailure
      onFailureRetries: 2
      onFailureRetryInterval: 10
      onSubmissionFailureRetries: 5
      onSubmissionFailureRetryInterval: 20
    driver:
      cores: 1
      coreLimit: "1200m"
      memory: "1024m"
      labels:
        version: 3.1.1
      serviceAccount: spark
    executor:
      coreRequest: "300m"
      coreLimit: "1000m"
      instances: 2
      memory: "2000m"
      labels:
        version: 3.1.1
      volumeMounts:
        - name: data
          mountPath: /mnt/spark
          readOnly: true