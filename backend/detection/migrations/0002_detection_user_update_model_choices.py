from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ("detection", "0001_initial"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.AddField(
            model_name="detection",
            name="user",
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="detections",
                to=settings.AUTH_USER_MODEL,
            ),
        ),
        migrations.AlterField(
            model_name="detection",
            name="model",
            field=models.CharField(
                choices=[
                    ("rtdetr-x", "RT-DETR-X"),
                    ("yolo26s", "YOLO26s"),
                    ("dfine-x", "D-FINE-X"),
                    ("dfine-s", "D-FINE-S"),
                    ("rfdetr-s", "RF-DETR-S"),
                    ("faster-rcnn", "Faster R-CNN"),
                ],
                max_length=20,
            ),
        ),
    ]
