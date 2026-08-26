# syntax=docker/dockerfile:1
# Athena backend — one image, two commands (api | worker).

FROM golang:1.26-alpine AS build
WORKDIR /src

COPY go.mod go.sum* ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/api ./cmd/api \
 && CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/worker ./cmd/worker

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/api /app/api
COPY --from=build /out/worker /app/worker
WORKDIR /app
EXPOSE 8080
CMD ["/app/api"]
