import os
from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.amazon.aws.operators.emr import EmrContainerOperator

# Retrieve target cluster configurations from environment or default parameters
VIRTUAL_CLUSTER_ID = os.environ.get("VIRTUAL_CLUSTER_ID", "abc123def456ghi789")
EXECUTION_ROLE_ARN = os.environ.get("EXECUTION_ROLE_ARN", "arn:aws:iam::123456789012:role/EMRJobExecutionRole")
ECR_REPO_URL = os.environ.get("ECR_REPO_URL", "123456789012.dkr.ecr.us-west-2.amazonaws.com/spark-emr-eks")
S3_BUCKET = os.environ.get("S3_BUCKET", "my-emr-eks-pod-templates-bucket")

default_args = {
    "owner": "data_engineering_team",
    "depends_on_past": False,
    "start_date": datetime(2026, 7, 28),
    "email_on_failure": False,
    "email_on_retry": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}

with DAG(
    dag_id="emr_eks_spark_pod_templates_dag",
    default_args=default_args,
    schedule_interval=None,  # Manual trigger
    catchup=False,
    tags=["emr", "eks", "spark", "pod_templates", "aws"],
    doc_md="""
    ### EMR on EKS PySpark Job Orchestration DAG
    This DAG orchestrates a Spark application running on Amazon EMR on EKS.
    It passes custom **Spark Configuration Parameters** and **Driver & Executor Pod Templates** 
    to customize Kubernetes Pod specifications (node selectors, volume mounts, GC options, labels).
    """,
) as dag:

    # Define EMR on EKS Container Job Run Task
    submit_emr_eks_spark_job = EmrContainerOperator(
        task_id="submit_spark_job_to_emr_eks",
        name="airflow-emr-eks-spark-pod-templates-job",
        virtual_cluster_id=VIRTUAL_CLUSTER_ID,
        execution_role_arn=EXECUTION_ROLE_ARN,
        release_label="emr-6.10.0-latest",
        job_driver={
            "sparkSubmitJobDriver": {
                "entryPoint": "local:///opt/spark/work-dir/spark_app.py",
                "sparkSubmitParameters": (
                    f"--conf spark.kubernetes.container.image={ECR_REPO_URL}:v1 "
                    f"--conf spark.kubernetes.driver.podTemplateFile=s3://{S3_BUCKET}/pod-templates/driver-pod-template.yaml "
                    f"--conf spark.kubernetes.executor.podTemplateFile=s3://{S3_BUCKET}/pod-templates/executor-pod-template.yaml "
                    "--conf spark.driver.memory=1024m "
                    "--conf spark.executor.memory=1024m "
                    "--conf spark.executor.instances=2 "
                    "--conf spark.sql.adaptive.enabled=true "
                    "--conf spark.sql.adaptive.coalescePartitions.enabled=true"
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
                        "spark.dynamicAllocation.enabled": "false",
                    },
                }
            ],
            "monitoringConfiguration": {
                "persistentAppUI": "ENABLED",
                "cloudWatchMonitoringConfiguration": {
                    "logGroupName": "/aws/emr-eks/spark-jobs",
                    "logStreamNamePrefix": "airflow-dag-job",
                },
                "s3MonitoringConfiguration": {
                    "logUri": f"s3://{S3_BUCKET}/logs/",
                },
            },
        },
        aws_conn_id="aws_default",
        wait_for_completion=True,
        poll_interval=15,
    )

    submit_emr_eks_spark_job
