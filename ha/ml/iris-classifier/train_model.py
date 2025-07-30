#!/usr/bin/env python3
"""
Iris Classifier Training Script for KServe Deployment
Trains a scikit-learn model on the Iris dataset and saves it for deployment.
"""

import os
import json
import pickle
import datetime
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.datasets import load_iris
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
import joblib


def load_and_prepare_data():
    """Load and prepare the Iris dataset."""
    print("📊 Loading Iris dataset...")
    
    # Load the iris dataset
    iris = load_iris()
    X, y = iris.data, iris.target
    
    # Create feature names
    feature_names = iris.feature_names
    target_names = iris.target_names
    
    print(f"Dataset shape: {X.shape}")
    print(f"Features: {feature_names}")
    print(f"Target classes: {target_names}")
    
    return X, y, feature_names, target_names


def train_model(X, y):
    """Train the Random Forest classifier."""
    print("🤖 Training Random Forest classifier...")
    
    # Split the data
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    
    # Create and train the model
    model = RandomForestClassifier(
        n_estimators=100,
        random_state=42,
        max_depth=10,
        min_samples_split=2,
        min_samples_leaf=1
    )
    
    model.fit(X_train, y_train)
    
    # Make predictions
    y_pred = model.predict(X_test)
    
    # Calculate accuracy
    accuracy = accuracy_score(y_test, y_pred)
    
    # Cross-validation score
    cv_scores = cross_val_score(model, X, y, cv=5)
    
    print(f"Test Accuracy: {accuracy:.4f}")
    print(f"Cross-validation scores: {cv_scores}")
    print(f"Mean CV accuracy: {cv_scores.mean():.4f} (+/- {cv_scores.std() * 2:.4f})")
    
    # Detailed classification report
    print("\nClassification Report:")
    print(classification_report(y_test, y_pred))
    
    # Confusion matrix
    print("\nConfusion Matrix:")
    print(confusion_matrix(y_test, y_pred))
    
    return model, accuracy, cv_scores.mean()


def save_model(model, accuracy, cv_accuracy, feature_names, target_names, output_dir):
    """Save the trained model and metadata."""
    print("💾 Saving model and metadata...")
    
    # Create output directory
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    
    # Save model using joblib (recommended for scikit-learn)
    model_path = output_path / "model.pkl"
    joblib.dump(model, model_path)
    print(f"Model saved to: {model_path}")
    
    # Create metadata
    metadata = {
        "model_name": "iris-classifier",
        "model_version": "v1",
        "framework": "scikit-learn",
        "algorithm": "RandomForestClassifier",
        "created_at": datetime.datetime.now().isoformat(),
        "accuracy": float(accuracy),
        "cv_accuracy": float(cv_accuracy),
        "feature_names": feature_names,
        "target_names": target_names.tolist(),
        "model_parameters": {
            "n_estimators": 100,
            "random_state": 42,
            "max_depth": 10,
            "min_samples_split": 2,
            "min_samples_leaf": 1
        },
        "input_schema": {
            "type": "array",
            "items": {
                "type": "array",
                "items": {"type": "number"},
                "minItems": 4,
                "maxItems": 4
            }
        },
        "output_schema": {
            "type": "object",
            "properties": {
                "predictions": {
                    "type": "array",
                    "items": {"type": "integer"}
                }
            }
        },
        "example_input": [[5.1, 3.5, 1.4, 0.2]],
        "example_output": {"predictions": [0]},
        "description": "Iris flower species classifier trained on the classic Iris dataset. Predicts species (setosa=0, versicolor=1, virginica=2) based on sepal and petal measurements."
    }
    
    # Save metadata
    metadata_path = output_path / "metadata.json"
    with open(metadata_path, 'w') as f:
        json.dump(metadata, f, indent=2)
    print(f"Metadata saved to: {metadata_path}")
    
    return model_path, metadata_path


def test_model(model_path, feature_names):
    """Test the saved model with sample data."""
    print("🧪 Testing saved model...")
    
    # Load the saved model
    loaded_model = joblib.load(model_path)
    
    # Test with sample data
    test_samples = [
        [5.1, 3.5, 1.4, 0.2],  # Should be setosa (0)
        [6.2, 2.9, 4.3, 1.3],  # Should be versicolor (1)
        [7.3, 2.9, 6.3, 1.8]   # Should be virginica (2)
    ]
    
    predictions = loaded_model.predict(test_samples)
    probabilities = loaded_model.predict_proba(test_samples)
    
    print("Test predictions:")
    for i, (sample, pred, prob) in enumerate(zip(test_samples, predictions, probabilities)):
        print(f"Sample {i+1}: {sample} -> Class {pred} (confidence: {prob.max():.3f})")
    
    return True


def main():
    """Main training pipeline."""
    print("🌸 Starting Iris Classifier Training Pipeline")
    print("=" * 50)
    
    # Set output directory
    output_dir = Path(__file__).parent
    
    try:
        # Load and prepare data
        X, y, feature_names, target_names = load_and_prepare_data()
        
        # Train model
        model, accuracy, cv_accuracy = train_model(X, y)
        
        # Check if accuracy meets requirements (>95%)
        if accuracy < 0.95:
            print(f"⚠️  Warning: Accuracy {accuracy:.4f} is below 95% threshold")
        else:
            print(f"✅ Accuracy {accuracy:.4f} meets the 95% requirement")
        
        # Save model and metadata
        model_path, metadata_path = save_model(
            model, accuracy, cv_accuracy, feature_names, target_names, output_dir
        )
        
        # Test the saved model
        test_model(model_path, feature_names)
        
        print("\n🎉 Training pipeline completed successfully!")
        print(f"Model saved to: {model_path}")
        print(f"Metadata saved to: {metadata_path}")
        print(f"Final accuracy: {accuracy:.4f}")
        
        return True
        
    except Exception as e:
        print(f"❌ Error during training: {str(e)}")
        return False


if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)
