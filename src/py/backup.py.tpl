import logging
from pyspark.sql import SparkSession
from pyspark.sql.functions import count
spark = SparkSession.builder.appName("GCSFilesReader") \
.config("spark.jars.packages", "com.microsoft.azure:synapseml_2.12:0.9.5") \
.config("spark.jars.repositories", "https://mmlspark.azureedge.net/maven") \
.config("spark.kubernetes.allocation.batch.size", 10) \
.getOrCreate()
df=spark.read.csv("gs://${staging_bucket}/data/input.csv", header=False)
df.select(count("*")).withColumnRenamed("count(*)","cnt").write.format("csv") \
.mode('overwrite').options(header="true").save("gs://${staging_bucket}/data/output-${service_sufix}.csv")
import os
db_name = 'ml_db'
spark.sql(f'DROP DATABASE IF EXISTS {db_name} CASCADE')
spark.sql(f'CREATE DATABASE {db_name}')
spark.sql(f'USE {db_name}')
table_name = "flights"  
spark.sql(f'DROP TABLE IF EXISTS {table_name}')
csv_path = 'gs://tbd-2022z-common/train-1m.csv'
spark.sql(f'CREATE TABLE IF NOT EXISTS {table_name} \
          USING csv \
          OPTIONS (HEADER true, INFERSCHEMA true, NULLVALUE "NA") \
          LOCATION "{csv_path}"')
from pyspark.ml.feature import StringIndexer, OneHotEncoder, VectorAssembler
from pyspark.ml import Pipeline
spark_df= spark.sql(f'SELECT * FROM {table_name}')
feature_columns = ['Month', 'DayofMonth', 'DayOfWeek',  'DepTime', 'UniqueCarrier', 'Origin', 'Dest', 'Distance']
stringindexer_stages = [StringIndexer(inputCol=c, outputCol='stringindexed_' + c).setHandleInvalid("keep") for c in feature_columns]
stringindexer_stages += [StringIndexer(inputCol='dep_delayed_15min', outputCol='label')]
onehotencoder_stages = [OneHotEncoder(inputCol='stringindexed_' + c, outputCol='onehot_' + c) for c in feature_columns]
extracted_columns = ['onehot_' + c for c in feature_columns]
vectorassembler_stage = VectorAssembler(inputCols=extracted_columns, outputCol='features') 
transformed_df = Pipeline(stages=stringindexer_stages + \
                          onehotencoder_stages + \
                          [vectorassembler_stage]).fit(spark_df).transform(spark_df)
training, test = transformed_df.randomSplit([0.8, 0.2], seed=1234)
from pyspark.ml.classification import LogisticRegression
lr = LogisticRegression(maxIter=100, regParam=0.3, elasticNetParam=0.8)
# Fit the model
import time
t = time.time()
lrModel = lr.fit(training)
elapsed_time = time.time() - t
df2 = spark.createDataFrame([{'elapsed_time':elapsed_time}])
df2.write.format("csv") \
.mode('overwrite').options(header="true").save("gs://${staging_bucket}/data/output-spark-ml.csv")

try:
    import synapse.ml
    from synapse.ml.lightgbm import LightGBMClassifier
    t = time.time()
    lgbm = LightGBMClassifier(objective="binary", labelCol="label", featuresCol="features")
    model = lgbm.fit(training)
    elapsed_time = time.time() - t
    df3 = spark.createDataFrame([{'elapsed_time':elapsed_time}])
    df3.write.format("csv") \
    .mode('overwrite').options(header="true").save("gs://${staging_bucket}/data/output-synapse-ml.csv")
except Exception as e:
    output = f"{e}"
    df4 = spark.createDataFrame([{'error':output}])
    df4.write.format("csv") \
    .mode('overwrite').options(header="true").save("gs://${staging_bucket}/data/output-synapse-ml-error.csv")
try:
    from pysparkling.ml import H2OXGBoost
    from pysparkling import *
    import h2o
    hc = H2OContext.getOrCreate() 
    estimator = H2OXGBoost(labelCol = "label").setFeaturesCols(feature_columns)
    import time
    t = time.time()
    model = estimator.fit(training)
    elapsed_time = time.time() - t
    df5 = spark.createDataFrame([{'elapsed_time':elapsed_time}])
    df5.write.format("csv") \
    .mode('overwrite').options(header="true").save("gs://${staging_bucket}/data/output-h2o.csv")
except Exception as e:
    output = f"{e}"
    df6 = spark.createDataFrame([{'error':output}])
    df6.write.format("csv") \
    .mode('overwrite').options(header="true").save("gs://${staging_bucket}/data/output-h2o-error.csv")
spark.stop()