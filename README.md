# metacatagory-act-ubuntu-agda

Custom `act` worker image with Agda 2.8.0 + stdlib + pandoc.

## Build (local, no registry cache)
```bash
docker build -t ghcr.io/mikemol/act-ubuntu-agda:latest .
```

## Build with registry-backed cache (BuildKit)
```bash
docker buildx build \
  -t ghcr.io/mikemol/act-ubuntu-agda:latest \
  --cache-from type=registry,ref=ghcr.io/mikemol/act-ubuntu-agda:buildcache \
  --cache-to type=registry,ref=ghcr.io/mikemol/act-ubuntu-agda:buildcache,mode=max \
  --load .
```

## Push
```bash
docker push ghcr.io/mikemol/act-ubuntu-agda:latest
```

## Act usage
Set your `.actrc` to:
```
-P ubuntu-latest=ghcr.io/mikemol/act-ubuntu-agda:latest
```
