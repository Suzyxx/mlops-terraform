import logging
from pipelines.ingest import Ingestion
from pipelines.clean import Cleaner
from pipelines.train import Trainer
from pipelines.predict import Predictor

logging.basicConfig(level=logging.INFO,format='%(asctime)s:%(levelname)s:%(message)s')

def main():
    # Load data
    ingestion = Ingestion()
    train, test = ingestion.load_data()
    logging.info("Data ingestion completed successfully")

    # Clean data
    cleaner = Cleaner()
    train_data = cleaner.clean_data(train)
    test_data = cleaner.clean_data(test)
    logging.info("Data cleaning completed successfully")

    # Prepare and train model
    trainer = Trainer()
    X_train, y_train = trainer.feature_target_separator(train_data)
    trainer.train_model(X_train, y_train)
    trainer.save_model()
    logging.info("Model training completed successfully")

    # Evaluate model
    predictor = Predictor()
    X_test, y_test = predictor.feature_target_separator(test_data)
    accuracy, class_report, roc_auc_score = predictor.evaluate_model(X_test, y_test)
    logging.info("Model evaluation completed successfully")

    # Print evaluation results
    print("\n============= Model Evaluation Results ==============")
    print(f"Model: {trainer.model_name}")
    print(f"Accuracy Score: {accuracy:.4f}, ROC AUC Score: {roc_auc_score:.4f}")
    print(f"\n{class_report}")
    print("=====================================================\n")


def mlflow_main():
    """The same pipeline as main(), but TRACKED with MLflow.

    Logs the run's parameters + metrics, logs the model artifact, and registers a
    new version in the MLflow Model Registry — so every experiment is recorded and
    comparable. Run locally, then view the experiments with:
        mlflow ui --backend-store-uri sqlite:///mlflow.db
    """
    import mlflow
    import mlflow.sklearn
    from sklearn.metrics import classification_report

    # Use a sqlite backend so the Model Registry works (the default file store
    # can't register models). The MLflow UI must point at this same db.
    mlflow.set_tracking_uri("sqlite:///mlflow.db")
    mlflow.set_experiment("Model Training Experiment")

    with mlflow.start_run() as run:
        # --- same ingest -> clean -> train -> evaluate steps as main() ---
        ingestion = Ingestion()
        train, test = ingestion.load_data()
        cleaner = Cleaner()
        train_data = cleaner.clean_data(train)
        test_data = cleaner.clean_data(test)

        trainer = Trainer()
        X_train, y_train = trainer.feature_target_separator(train_data)
        trainer.train_model(X_train, y_train)
        trainer.save_model()

        predictor = Predictor()
        X_test, y_test = predictor.feature_target_separator(test_data)
        accuracy, class_report, roc_auc = predictor.evaluate_model(X_test, y_test)
        report = classification_report(
            y_test, predictor.pipeline.predict(X_test), output_dict=True)

        # --- log the experiment: parameters... ---
        mlflow.log_param("model_name", trainer.model_name)
        mlflow.log_params(trainer.model_params)

        # ...and performance metrics
        mlflow.log_metric("accuracy", accuracy)
        mlflow.log_metric("roc_auc", roc_auc)
        mlflow.log_metric("precision", report["weighted avg"]["precision"])
        mlflow.log_metric("recall", report["weighted avg"]["recall"])

        # --- log the model (with an input/output signature) and register it ---
        signature = mlflow.models.infer_signature(
            X_train, trainer.pipeline.predict(X_test))
        mlflow.sklearn.log_model(
            trainer.pipeline, artifact_path="model", signature=signature)
        mlflow.register_model(f"runs:/{run.info.run_id}/model", "insurance_model")

        logging.info(
            f"MLflow run {run.info.run_id} logged: "
            f"accuracy={accuracy:.4f}, roc_auc={roc_auc:.4f}")


if __name__ == "__main__":
    main()
