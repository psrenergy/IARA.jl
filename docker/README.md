# Building image

Run


```bash
docker build . -t iara-jl-container --build-arg IARA_URL=PATH_TO_IARA_PUBLISHED_VERSION
```


# Storage

The case files are read from and written to the bucket `S3_BUCKET`. `STORAGE_PROVIDER` picks the server:

- `s3` (default): AWS S3, with the usual `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` and `AWS_DEFAULT_REGION`.
- `minio`: a MinIO server at `S3_ENDPOINT_URL` (e.g. `http://minio:9000`), with the MinIO credentials in `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`. The container must be able to reach that URL, e.g. by joining the MinIO container's Docker network.
