#!/usr/bin/env python3
"""
Iris Classifier API Testing Script
Tests the deployed KServe InferenceService API endpoint.
"""

import json
import time
import requests
from typing import List, Dict, Any
import numpy as np


class IrisAPITester:
    """Test client for Iris Classifier API."""
    
    def __init__(self, base_url: str):
        """Initialize the API tester.
        
        Args:
            base_url: Base URL of the KServe InferenceService
        """
        self.base_url = base_url.rstrip('/')
        self.model_name = "iris-classifier"
        self.session = requests.Session()
        
        # Test data samples
        self.test_samples = {
            "setosa": [5.1, 3.5, 1.4, 0.2],
            "versicolor": [6.2, 2.9, 4.3, 1.3],
            "virginica": [7.3, 2.9, 6.3, 1.8]
        }
        
        # Expected predictions (0=setosa, 1=versicolor, 2=virginica)
        self.expected_predictions = {
            "setosa": 0,
            "versicolor": 1,
            "virginica": 2
        }
    
    def health_check(self) -> bool:
        """Check if the API is healthy and responsive."""
        print("🏥 Performing health check...")
        
        try:
            # Check model metadata endpoint
            url = f"{self.base_url}/v1/models/{self.model_name}"
            response = self.session.get(url, timeout=10)
            
            if response.status_code == 200:
                metadata = response.json()
                print(f"✅ Model '{self.model_name}' is ready")
                print(f"   Model version: {metadata.get('spec', {}).get('version', 'unknown')}")
                return True
            else:
                print(f"❌ Health check failed: {response.status_code}")
                print(f"   Response: {response.text}")
                return False
                
        except requests.exceptions.RequestException as e:
            print(f"❌ Health check failed: {str(e)}")
            return False
    
    def test_single_prediction(self, sample: List[float], expected_class: int = None) -> Dict[str, Any]:
        """Test a single prediction request.
        
        Args:
            sample: Input features [sepal_length, sepal_width, petal_length, petal_width]
            expected_class: Expected prediction class (optional)
            
        Returns:
            Dictionary with test results
        """
        url = f"{self.base_url}/v1/models/{self.model_name}:predict"
        
        payload = {
            "instances": [sample]
        }
        
        try:
            start_time = time.time()
            response = self.session.post(
                url,
                json=payload,
                headers={"Content-Type": "application/json"},
                timeout=30
            )
            latency = (time.time() - start_time) * 1000  # Convert to milliseconds
            
            if response.status_code == 200:
                result = response.json()
                predictions = result.get("predictions", [])
                
                if predictions:
                    predicted_class = predictions[0]
                    
                    test_result = {
                        "success": True,
                        "input": sample,
                        "predicted_class": predicted_class,
                        "expected_class": expected_class,
                        "correct": predicted_class == expected_class if expected_class is not None else None,
                        "latency_ms": round(latency, 2),
                        "response": result
                    }
                    
                    return test_result
                else:
                    return {
                        "success": False,
                        "error": "No predictions in response",
                        "response": result
                    }
            else:
                return {
                    "success": False,
                    "error": f"HTTP {response.status_code}: {response.text}",
                    "latency_ms": round(latency, 2)
                }
                
        except requests.exceptions.RequestException as e:
            return {
                "success": False,
                "error": f"Request failed: {str(e)}"
            }
    
    def test_batch_prediction(self, samples: List[List[float]]) -> Dict[str, Any]:
        """Test batch prediction request.
        
        Args:
            samples: List of input feature arrays
            
        Returns:
            Dictionary with test results
        """
        print(f"🔄 Testing batch prediction with {len(samples)} samples...")
        
        url = f"{self.base_url}/v1/models/{self.model_name}:predict"
        
        payload = {
            "instances": samples
        }
        
        try:
            start_time = time.time()
            response = self.session.post(
                url,
                json=payload,
                headers={"Content-Type": "application/json"},
                timeout=30
            )
            latency = (time.time() - start_time) * 1000
            
            if response.status_code == 200:
                result = response.json()
                predictions = result.get("predictions", [])
                
                return {
                    "success": True,
                    "input_count": len(samples),
                    "prediction_count": len(predictions),
                    "predictions": predictions,
                    "latency_ms": round(latency, 2),
                    "avg_latency_per_sample": round(latency / len(samples), 2)
                }
            else:
                return {
                    "success": False,
                    "error": f"HTTP {response.status_code}: {response.text}",
                    "latency_ms": round(latency, 2)
                }
                
        except requests.exceptions.RequestException as e:
            return {
                "success": False,
                "error": f"Request failed: {str(e)}"
            }
    
    def performance_test(self, num_requests: int = 10) -> Dict[str, Any]:
        """Run performance test with multiple requests.
        
        Args:
            num_requests: Number of requests to send
            
        Returns:
            Performance statistics
        """
        print(f"⚡ Running performance test with {num_requests} requests...")
        
        latencies = []
        successes = 0
        failures = 0
        
        # Use a representative sample
        test_sample = self.test_samples["versicolor"]
        
        for i in range(num_requests):
            result = self.test_single_prediction(test_sample)
            
            if result["success"]:
                successes += 1
                latencies.append(result["latency_ms"])
            else:
                failures += 1
                print(f"   Request {i+1} failed: {result.get('error', 'Unknown error')}")
        
        if latencies:
            return {
                "total_requests": num_requests,
                "successes": successes,
                "failures": failures,
                "success_rate": round((successes / num_requests) * 100, 2),
                "avg_latency_ms": round(np.mean(latencies), 2),
                "min_latency_ms": round(min(latencies), 2),
                "max_latency_ms": round(max(latencies), 2),
                "p95_latency_ms": round(np.percentile(latencies, 95), 2),
                "p99_latency_ms": round(np.percentile(latencies, 99), 2)
            }
        else:
            return {
                "total_requests": num_requests,
                "successes": 0,
                "failures": failures,
                "success_rate": 0.0,
                "error": "All requests failed"
            }
    
    def run_comprehensive_test(self) -> bool:
        """Run comprehensive test suite."""
        print("🧪 Starting Comprehensive API Test Suite")
        print("=" * 50)
        
        all_tests_passed = True
        
        # 1. Health check
        if not self.health_check():
            print("❌ Health check failed - aborting tests")
            return False
        
        print()
        
        # 2. Test individual samples
        print("🔍 Testing individual predictions...")
        for species, sample in self.test_samples.items():
            expected = self.expected_predictions[species]
            result = self.test_single_prediction(sample, expected)
            
            if result["success"]:
                correct = "✅" if result["correct"] else "❌"
                print(f"   {species}: {correct} Predicted {result['predicted_class']}, Expected {expected} ({result['latency_ms']}ms)")
                
                if not result["correct"]:
                    all_tests_passed = False
            else:
                print(f"   {species}: ❌ Failed - {result['error']}")
                all_tests_passed = False
        
        print()
        
        # 3. Test batch prediction
        all_samples = list(self.test_samples.values())
        batch_result = self.test_batch_prediction(all_samples)
        
        if batch_result["success"]:
            print(f"✅ Batch prediction: {batch_result['prediction_count']} predictions in {batch_result['latency_ms']}ms")
            print(f"   Average latency per sample: {batch_result['avg_latency_per_sample']}ms")
        else:
            print(f"❌ Batch prediction failed: {batch_result['error']}")
            all_tests_passed = False
        
        print()
        
        # 4. Performance test
        perf_result = self.performance_test(10)
        
        if "error" not in perf_result:
            print(f"⚡ Performance test results:")
            print(f"   Success rate: {perf_result['success_rate']}%")
            print(f"   Average latency: {perf_result['avg_latency_ms']}ms")
            print(f"   95th percentile: {perf_result['p95_latency_ms']}ms")
            print(f"   99th percentile: {perf_result['p99_latency_ms']}ms")
            
            # Check if latency meets requirements (<100ms)
            if perf_result['avg_latency_ms'] > 100:
                print(f"   ⚠️  Average latency exceeds 100ms requirement")
                all_tests_passed = False
            else:
                print(f"   ✅ Latency meets <100ms requirement")
        else:
            print(f"❌ Performance test failed: {perf_result['error']}")
            all_tests_passed = False
        
        print()
        print("=" * 50)
        
        if all_tests_passed:
            print("🎉 All tests passed successfully!")
        else:
            print("❌ Some tests failed - check the results above")
        
        return all_tests_passed


def main():
    """Main function to run API tests."""
    import argparse
    
    parser = argparse.ArgumentParser(description="Test Iris Classifier API")
    parser.add_argument(
        "--url",
        default="https://iris-classifier.ml.hashfoundry.local",
        help="Base URL of the KServe InferenceService"
    )
    parser.add_argument(
        "--performance-requests",
        type=int,
        default=10,
        help="Number of requests for performance test"
    )
    
    args = parser.parse_args()
    
    # Create tester instance
    tester = IrisAPITester(args.url)
    
    # Run comprehensive test
    success = tester.run_comprehensive_test()
    
    # Exit with appropriate code
    exit(0 if success else 1)


if __name__ == "__main__":
    main()
