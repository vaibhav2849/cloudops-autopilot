import json, os, boto3
from botocore.exceptions import ClientError

ec2=boto3.client("ec2")
AUTO_TAG_KEY=os.getenv("AUTO_TAG_KEY","AutoRemediate")

def lambda_handler(event, context):
    print("Received event:",json.dumps(event))
    detail=event.get("detail",{})
    instance_id=detail.get("instance-id")
    state=detail.get("state")
    if not instance_id:
        return {"status":"ignored","reason":"missing instance id"}
    try:
        r=ec2.describe_instances(InstanceIds=[instance_id])
        instances=r.get("Reservations",[])
        if not instances or not instances[0]["Instances"]:
            return {"status":"ignored","reason":"instance not found"}
        instance=instances[0]["Instances"][0]
        tags={x["Key"]:x["Value"] for x in instance.get("Tags",[])}
        if tags.get(AUTO_TAG_KEY,"false").lower()!="true":
            return {"status":"ignored","reason":"auto remediation disabled"}
        action="no_action"
        if state=="stopped":
            ec2.start_instances(InstanceIds=[instance_id])
            action="start_instances"
        print(json.dumps({"instance_id":instance_id,"state":state,"action":action}))
        return {"status":"success","instance_id":instance_id,"action":action}
    except ClientError as exc:
        print(str(exc))
        raise
