import json
import os
import tempfile
import time

from pathlib import Path
from typing import Any, Dict, Optional, Union

import boto3

from botocore.exceptions import ClientError

from .globals import logger

_bucket = boto3.resource("s3").Bucket(os.getenv("S3_BUCKET", ""))
_lambda = boto3.client("lambda")
_lambda_prefix = os.getenv("LAMBDA_PREFIX", "")
_table = boto3.resource("dynamodb").Table(os.getenv("DYNAMODB_TABLE", ""))


def ddb_get_item(key: str) -> Optional[Dict[str, str]]:
    """Get an item from DynamoDB."""
    logger.debug(f"Getting item: {key}")
    resp = _table.get_item(Key={"id": key})
    if "Item" not in resp:
        logger.warning(f"Key {key} not found in DynamoDB")
        return None
    item = resp["Item"]
    if "ttl" in item:
        del item["ttl"]
    return item


def ddb_put_item(key: str, item: Dict[str, str], ttl: bool = False) -> None:
    """Put an item into DynamoDB."""
    logger.debug(f"Putting item: {key}")
    item["id"] = key
    if ttl:
        item["ttl"] = str(round(time.time()) + 60 * 60 * 24 * 14)  # Two weeks.
    _table.put_item(Item=item)


def ddb_update_item(key: str, item: Dict[str, str]) -> None:
    """Update an item in DynamoDB."""
    logger.debug("Updating item: {key}")
    updates = {k: {"Value": v} for k, v in item.items()}
    _table.update_item(Key={"id": key}, AttributeUpdates=updates)


def s3_get_object(key: str, dest: Optional[Path] = None) -> Optional[Path]:
    """Download a file from S3 and return the path on disk."""
    logger.debug(f"Downloading object: {key}")
    if dest is None:
        _, path = tempfile.mkstemp()
        dest = Path(path)
    try:
        _bucket.download_file(key, str(dest))
    except ClientError as e:
        if e.response["Error"]["Message"] == "Not Found":
            logger.warning(f"Object {key} not found")
        else:
            logger.exception("S3 get object failed")
        return None
    return dest


def s3_put_object(key: str, source: Path) -> None:
    """Upload a file to S3."""
    logger.debug(f"Uploading object: {key}")
    with open(source) as f:
        # TODO: Why doesn't passing the open file work?
        _bucket.put_object(Key=key, Body=f.read().encode("utf-8"))


def lambda_invoke_function(function: str, payload: str) -> None:
    """Invoke a Lambda function."""
    logger.debug(f"Invoking function: {function}")
    _lambda.invoke(
        FunctionName=_lambda_prefix + function,
        Payload=json.dumps(payload),
        InvocationType="Event",
    )
