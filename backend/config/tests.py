from django.test import TestCase
from django.urls import reverse


class HomeViewTests(TestCase):
    def test_home_returns_api_status(self):
        response = self.client.get(reverse("home"))

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {
                "message": "BirdVision AI API",
                "status": "online",
                "endpoint": "/api/detect/",
            },
        )
