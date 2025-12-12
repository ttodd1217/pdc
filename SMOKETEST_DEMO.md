# Smoketest / Demo Script (5 minutes)

This file contains a concise, copy-pasteable demo script and checks I ran when validating a PDC deployment. Use PowerShell on Windows and bash on Linux/macOS where noted.

> High-level goal: prove ALB + app + ingestion pipeline + SFTP are working and that alerts fire when ingestion fails.

---

## 1) PowerShell: read outputs and secret into variables

Run from `terraform/` directory after a successful apply.

```powershell
cd terraform
$ALB_DNS   = terraform output -raw alb_dns_name
$SFTP_IP   = terraform output -raw sftp_ec2_public_ip
$S3_BUCKET = terraform output -raw sftp_data_bucket
$API_KEY   = aws secretsmanager get-secret-value --secret-id pdc/alert-api-key --region us-east-2 --query SecretString --output text

"ALB: $ALB_DNS"
"SFTP: $SFTP_IP"
"S3: $S3_BUCKET"
```

Notes:
- On Linux/macOS replace `terraform output -raw` with the same commands (they work there). For secrets you may prefer `--query SecretString` and parse JSON if the secret contains multiple keys.
- Confirm the secret name is correct (see step 2 below). If your API expects a different secret name, retrieve that instead.

---

## 2) Confirm what secrets the app task injects

This ensures you read the right secret name and mapping (env var or secrets manager ARN).

```bash
aws ecs describe-task-definition --task-definition pdc-app --region us-east-2 --query "taskDefinition.containerDefinitions[0].secrets" --output table
```

Look for `name`/`valueFrom` entries. `valueFrom` will show the Secrets Manager ARN/secret-id that the container reads.

---

## 3) Health endpoint: hit the listener you exposed

If you have an ALB listener on port 80 (HTTP):

```powershell
# Windows PowerShell
curl.exe -i "http://$ALB_DNS/health"
```

On Linux/macOS:

```bash
curl -i "http://$ALB_DNS/health"
```

If your ALB uses HTTPS (port 443) use `https://` and add `-k` to curl if self-signed certs are used.

Expect: 200 OK and a JSON body indicating DB and ingestion health. If authentication is required, include `-H "x-api-key: $API_KEY"`.

---

## 4) SFTP port checks (quick answer whether ports are reachable)

Use these to prove port 22 (standard) or 3022 (container mapping) is reachable from your test runner.

```powershell
Test-NetConnection $SFTP_IP -Port 22
Test-NetConnection $SFTP_IP -Port 3022
```

If `TcpTestSucceeded` is False, the port is blocked or the instance is not listening.

Also, on the server, check the SSH daemon:

```bash
# on Ubuntu / Debian
sudo systemctl status sshd || sudo systemctl status ssh
```

---

## 5) Prove ingestion and DB rows (sample data proof)

Upload a small sample file to the exact S3 prefix your EventBridge rule watches.

First confirm the EventBridge rule pattern (so you upload to correct prefix):

```bash
aws events describe-rule --name pdc-s3-sftp-file-upload --region us-east-2 --query EventPattern --output text
```

If the event pattern watches `s3:ObjectCreated:*` with `prefix` set to `uploads/`, upload to `uploads/`.

Upload file (local/demo.csv -> s3://bucket/uploads/demo.csv):

```bash
aws s3 cp ../data/example_format1.csv s3://$S3_BUCKET/uploads/demo-$(Get-Date -Format yyyyMMddHHmmss).csv
```

Now tail the ingestion logs to watch the job start and complete:

```bash
aws logs tail /ecs/pdc-ingestion-v2 --follow --region us-east-2
```

Expect log lines showing the ECS task started, processed the file, and (optionally) wrote a DB row.

Finally, verify via the API (or directly against the DB) that the ingested data is present. Example API check:

```bash
# Query blotter for a date you're confident appears in the sample data
curl -s "http://$ALB_DNS/api/blotter?date=2025-01-15" | jq '.'
```

If the API is authenticated, include the API key header: `-H "x-api-key: $API_KEY"`.

Optional DB check (if you have psql access):

```bash
psql "host=<rds-endpoint> user=<user> password=<pass> dbname=pdc_db" -c "select count(*) from ingestion_table where created_at::date='2025-01-15';"
```

---

## 6) Smoketest alerts: provoke and verify one alert

Add a failing step to trigger the alert path (for example point the ingestion to an invalid URL, or upload a file that causes a processing error). Keep it minimal and reversible.

Example: trigger a deliberate failure in the ingestion worker by uploading a malformed file (or temporarily set environment in the task to a bad downstream URL) and then run the smoke test.

Steps:

1. Upload a file that will fail processing (e.g., wrong format) to the watched prefix.
2. Tail ingestion logs and confirm an ERROR stack trace.
3. Confirm alert: check Slack/alert webhook or look for an outgoing HTTP call in the mock alert service logs.

For a simple scripted check, run the existing smoke test (if provided):

```bash
# run from repo root
python3 scripts/smoketest.py
# or the test harness you have that sends an alert on failure
```

Watch the alerting sink (Slack channel, webhook endpoint, or the mock_alert_service in `scripts/`).

---

## 7) Minimal 5-minute demo script (what to say / run)

1. Show ALB health:

```powershell
curl.exe -i "http://$ALB_DNS/health"
```

2. Show logs following ingestion:

```bash
aws logs tail /ecs/pdc-ingestion-v2 --follow --region us-east-2
```

3. Upload sample file to watched prefix:

```bash
aws s3 cp ../data/example_format1.csv s3://$S3_BUCKET/uploads/demo-$(date +%s).csv
```

4. Show logs: watch for a successful processing message.

5. Query API to show data present:

```bash
curl -s "http://$ALB_DNS/api/blotter?date=2025-01-15" | jq '.'
```

6. (Optional) SFTP upload to show human path:

```bash
sftp -i terraform/pdc-sftp-server-key.pem sftp_user@$SFTP_IP
sftp> put ../data/example_format1.csv
sftp> bye
```

7. Show alerts (if you triggered one): check Slack channel or mock alert logs.

---

## Troubleshooting notes

- If `terraform output -raw` returns empty strings, confirm `terraform apply` completed successfully and that outputs are defined in `terraform/outputs.tf`.
- If `aws ecs describe-task-definition` shows no secrets: the app may use env vars instead of Secrets Manager. Check container definitions for `environment` and `secrets` fields.
- If S3 upload doesn't trigger ingestion, check that the bucket name and prefix used in the EventBridge rule exactly match your uploaded key.
- If ports are blocked, confirm Security Groups and NACLs for the EC2 instance and NAT/GW settings.

---

## Safety & cleanup

- After demos, remove demo files from S3 to avoid re-triggering ingestion:

```bash
aws s3 rm s3://$S3_BUCKET/uploads/demo-*.csv
```

- If you created temporary IAM roles or test secrets, delete them when finished.

---

If you'd like, I can commit this file into the repo under `SMOKETEST_DEMO.md` (I will do that now).