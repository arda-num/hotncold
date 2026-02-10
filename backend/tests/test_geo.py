"""Tests for geo utility functions."""

import pytest
from app.services.geo import haversine_distance


class TestHaversine:
    def test_same_point_returns_zero(self):
        assert haversine_distance(41.0, 29.0, 41.0, 29.0) == 0.0

    def test_known_distance_istanbul(self):
        """Taksim to Kadıköy ≈ 5.5 km"""
        dist = haversine_distance(41.0370, 28.9850, 40.9903, 29.0291)
        assert 5000 < dist < 6500

    def test_antipodal_points(self):
        """North pole to south pole ≈ 20,000 km"""
        dist = haversine_distance(90, 0, -90, 0)
        assert abs(dist - 20_015_086) < 1000  # within 1km tolerance

    def test_short_distance(self):
        """Two points ~100m apart"""
        dist = haversine_distance(41.0370, 28.9850, 41.0379, 28.9850)
        assert 90 < dist < 110
