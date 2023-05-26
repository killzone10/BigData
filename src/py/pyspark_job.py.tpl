import logging
from pyspark.sql import SparkSession
from pyspark.sql.functions import count
import pyspark.sql.functions as F

spark = SparkSession.builder.appName("GCSFilesReader") \
.config("spark.jars.packages", "com.microsoft.azure:synapseml_2.12:0.9.5") \
.config("spark.jars.repositories", "https://mmlspark.azureedge.net/maven") \
.config("spark.kubernetes.allocation.batch.size", 10) \
.getOrCreate()

df=spark.read.csv("gs://tbd-2022z-101-staging/data/ml/input/ds1_1e6.csv", header=False)

df.select(count("*")).withColumnRenamed("count(*)","cnt").write.format("csv") \
.mode('overwrite').options(header="true").save("gs://tbd-2022z-101-staging/data/ml/output/${service_sufix}.csv")

import os
db_name = 'ml_db'
spark.sql(f'DROP DATABASE IF EXISTS {db_name} CASCADE')
spark.sql(f'CREATE DATABASE {db_name}')
spark.sql(f'USE {db_name}')
#table_name = "flights"  
table_name = "accidents"  
spark.sql(f'DROP TABLE IF EXISTS {table_name}')

csv_path =  'gs://tbd-2022z-101-staging/data/ml/input/ds1_1e6.csv'

spark.sql(f'CREATE TABLE IF NOT EXISTS {table_name} \
          USING csv \
          OPTIONS (HEADER true, INFERSCHEMA true, NULLVALUE "NA") \
          LOCATION "{csv_path}"')

from pyspark.ml.feature import StringIndexer, OneHotEncoder, VectorAssembler
from pyspark.ml import Pipeline

#------------------creating training data 
spark_df= spark.sql(f'SELECT * FROM {table_name}')
spark_df = spark_df.withColumn('label', F.when(spark_df.label == 'false', 0).otherwise(1))
y = 'label'
feature_columns = ['Pedestrian_Crossing-Human_Control','Carriageway_Hazards','Special_Conditions_at_Site','Urban_or_Rural_Area','Road_Surface_Conditions',
                   'Road_Type','Junction_Control','Pedestrian_Crossing-Physical_Facilities', 'Weather_Conditions',
                   'Did_Police_Officer_Attend_Scene_of_Accident','2nd_Road_Class', '1st_Road_Class','Speed_limit', '2nd_Road_Number',
                   'Number_of_Vehicles','Number_of_Casualties']

stringindexer_stages = [StringIndexer(inputCol=c, outputCol='stringindexed_' + c).setHandleInvalid("keep") for c in feature_columns]
onehotencoder_stages = [OneHotEncoder(inputCol='stringindexed_' + c, outputCol='onehot_' + c) for c in feature_columns]
onehotencoder_stages = [OneHotEncoder(inputCol='stringindexed_' + c, outputCol='onehot_' + c) for c in feature_columns]
extracted_columns = ['onehot_' + c for c in feature_columns]
vectorassembler_stage = VectorAssembler(inputCols=extracted_columns, outputCol='features')
transformed_df = Pipeline(stages=stringindexer_stages + \
                          onehotencoder_stages + \
                          [vectorassembler_stage] \
                         ).fit(spark_df).transform(spark_df)
training, test = transformed_df.randomSplit([0.8, 0.2], seed=1234)

CLUSTER = 'k8s'
GROUP = 'tbd_2022z_101'
SPARK_EXC = 6

for i in range(3):

    #----------sparkML
    LIBRARY = 'spark_ml'

    #------LogisticRegression
    MODEL = 'LR'
    from pyspark.ml.classification import LogisticRegression, GBTClassifier
    lr = LogisticRegression(featuresCol='features', labelCol='label', regParam = 0.3)
    # Fit the model
    import time
    t = time.time()
    lrModel = Pipeline(stages=[lr]).fit(training)
    elapsed_time = time.time() - t
    spark_ml_lr_data = {'group': GROUP,
                                'cluster': CLUSTER,
                                'model': MODEL,
                                'library' : LIBRARY,
                                'spark-executors': SPARK_EXC,
                                'elapsed_time':elapsed_time}
    df_ml_lr = spark.createDataFrame([spark_ml_lr_data])
    df_ml_lr.write.format("csv") \
    .mode('append').options(header="true").save(f"gs://${staging_bucket}/data/ml/output/output_{CLUSTER}_{SPARK_EXC}.csv")


    #----GBT
    MODEL = 'GBT'
    gbt = GBTClassifier(labelCol="label", featuresCol="features", maxIter=10)
    t = time.time()
    GbtModel = Pipeline(stages=[gbt]).fit(training)
    elapsed_time = time.time() - t
    spark_ml_gbt_data = {'group': GROUP,
                                'cluster': CLUSTER,
                                'model': MODEL,
                                'library' : LIBRARY,
                                'spark-executors': SPARK_EXC,
                                'elapsed_time':elapsed_time}


    df_ml_GBT = spark.createDataFrame([spark_ml_gbt_data])
    df_ml_GBT.write.format("csv") \
    .mode('append').options(header="true").save(f"gs://${staging_bucket}/data/ml/output/output_{CLUSTER}_{SPARK_EXC}.csv")



    #----------synapese.ml
    LIBRARY = 'synapse-ml'

    import synapse.ml

    #------LR
    MODEL = 'LR'

    #from synapse.ml.train import TrainClassifier
    #from pyspark.ml.classification import LogisticRegression
    ## Fit the model
    #import time
    #t = time.time()
    #lr_model_synapse = TrainClassifier(model=LogisticRegression(), labelCol='label', featuresCol='features').fit(training)
    #elapsed_time = time.time() - t
    #spark_syn_lr_data = {'group': GROUP,
    #                            'cluster': CLUSTER,
    #                            'model': MODEL,
    #                            'library' : LIBRARY,
    #                            'spark-executors': SPARK_EXC,
    #                            'elapsed_time':elapsed_time}
    #df_syn_lr = spark.createDataFrame([spark_syn_lr_data])
    #df_syn_lr.write.format("csv") \
    #.mode('append').options(header="true").save(f"gs://${staging_bucket}/data/ml/output/output_{CLUSTER}_{SPARK_EXC}.csv")

    #------GBT
    MODEL = 'GBT'

    from synapse.ml.lightgbm import LightGBMClassifier
    t = time.time()
    lgbm = LightGBMClassifier(objective="binary", labelCol="label", featuresCol="features", isUnbalance=True)
    model = Pipeline(stages=[lgbm]).fit(training)
    elapsed_time = time.time() - t
    synapse_gbt_data = {'group': GROUP,
                              'cluster': CLUSTER,
                              'model': MODEL,
                              'library' : LIBRARY,
                              'spark-executors': SPARK_EXC,
                              'elapsed_time':elapsed_time}


    df_syn_GBM = spark.createDataFrame([synapse_gbt_data])
    df_syn_GBM.write.format("csv") \
    .mode('append').options(header="true").save(f"gs://${staging_bucket}/data/ml/output/output_{CLUSTER}_{SPARK_EXC}.csv")



    #----------h20
    LIBRARY = 'h20'

    from pysparkling.ml import H2OGLM
    from pysparkling.ml import H2OXGBoostClassifier

    from pysparkling.ml import H2OXGBoost
    from pysparkling import *
    import h2o
    hc = H2OContext.getOrCreate() 

    #------LR
    MODEL = 'LR'
    lr_h2o = H2OGLM(family='binomial', featuresCols=['features'], labelCol='label', detailedPredictionCol='rawPrediction_u')
    # Fit the model
    t = time.time()
    simple_model_h2o = Pipeline(stages=[lr_h2o]).fit(training)
    elapsed_time = time.time() - t
    h20_lr_data = {'group': GROUP,
                                'cluster': CLUSTER,
                                'model': MODEL,
                                'library' : LIBRARY,
                                'spark-executors': SPARK_EXC,
                                'elapsed_time':elapsed_time}
    h20_lr = spark.createDataFrame([h20_lr_data])
    h20_lr.write.format("csv") \
    .mode('append').options(header="true").save(f"gs://${staging_bucket}/data/ml/output/output_{CLUSTER}_{SPARK_EXC}.csv")


    #------GBT
    MODEL = 'GBT'

    model = H2OXGBoostClassifier(labelCol = "label", featuresCols=['features'])
    t = time.time()
    model_trained = Pipeline(stages=[model]).fit(training)
    elapsed_time = time.time() - t
    synapse_gbt_data = {'group': GROUP,
                              'cluster': CLUSTER,
                              'model': MODEL,
                              'library' : LIBRARY,
                              'spark-executors': SPARK_EXC,
                              'elapsed_time':elapsed_time}
    synapse_gbt = spark.createDataFrame([synapse_gbt_data])
    synapse_gbt.write.format("csv") \
    .mode('append').options(header="true").save(f"gs://${staging_bucket}/data/ml/output/output_{CLUSTER}_{SPARK_EXC}.csv")

spark.stop()