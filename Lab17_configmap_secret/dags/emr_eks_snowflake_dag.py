import os
from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.amazon.aws.operators.emr import EmrContainerOperator

VIRTUAL_CLUSTER_ID = os.environ.get("VIRTUAL_CLUSTER_ID", "abc123def456ghi789")
EXECUTION_ROLE_ARN = os.environ.get("EXECUTION_ROLE_ARN", "arn:aws:iam::123456789012:role/EMRJobExecutionRole")
ECR_REPO_URL = os.environ.get("ECR_REPO_URL", "123456789012.dkr.ecr.us-west-2.amazonaws.com/spark-emr-eks")
S3_BUCKET = os.environ.get("S3_BUCKET", "my-emr-eks-pod-templates-bucket")

default_args = {
    "owner": "data_engineering_team",
    "depends_on_past": False,
    "start_date": datetime(2026, 7, 28),
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}

with DAG(
    dag_id="emr_eks_s3_to_snowflake_pipeline_dag",
    default_args=default_args,
    schedule_interval=None,
    catchup=False,
    tags=["emr", "eks", "spark", "s3", "snowflake", "configmap", "secret"],
    doc_md="""
    ### EMR on EKS PySpark S3 to Snowflake Pipeline DAG
    This DAG orchestrates a PySpark application on Amazon EMR on EKS.
    The job uses **Kubernetes ConfigMap (`app-config`)** and **Secret (`app-secret`)** 
    injected via Driver and Executor Pod Templates to securely fetch S3 paths and Snowflake credentials.
    """,
) as dag:

    submit_spark_snowflake_job = EmrContainerOperator(
        task_id="submit_spark_s3_to_snowflake_job",
        name="airflow-emr-eks-s3-snowflake-job",
        virtual_cluster_id=VIRTUAL_CLUSTER_ID,
        execution_role_arn=EXECUTION_ROLE_ARN,
        release_label="emr-6.10.0-latest",
        job_driver={
            "sparkSubmitJobDriver": {
                "entryPoint": "local:///opt/spark/work-dir/spark_s3_to_snowflake.py",
                "sparkSubmitParameters": (
                    f"--conf spark.kubernetes.container.image={ECR_REPO_URL}:v1 "
                    f"--conf spark.kubernetes.driver.podTemplateFile=s3://{S3_BUCKET}/pod-templates/driver-pod-template.yaml "
                    f"--conf spark.kubernetes.executor.podTemplateFile=s3://{S3_BUCKET}/pod-templates/executor-pod-template.yaml "
                    "--packages net.snowflake:spark-snowflake_2.12:2.12.0-spark_3.3 "
                    "--conf spark.driver.memory=1024m "
                    "--conf spark.executor.memory=1024m "
                    "--conf spark.executor.instances=2 "
                    "--conf spark.sql.adaptive.enabled=true"
                ),
            }
        },
        configuration_overrides={
            "applicationConfiguration": [
                {
                    "classification": "spark-defaults",
                    "properties": {
                        "spark.driver.cores": "1",
                        "spark.executor.cores": "1",
                    },
                }
            ],
            "monitoringConfiguration": {
                "persistentAppUI": "ENABLED",
                "s3MonitoringConfiguration": {
                    "logUri": f"s3://{S3_BUCKET}/logs/",
                },
            },
        },
        aws_conn_id="aws_default",
        wait_for_completion=True,
        poll_interval=15,
    )

    submit_spark_snowflake_job
