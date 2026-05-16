# Stage 1: Build
FROM --platform=$BUILDPLATFORM golang:1.26-alpine AS builder

RUN apk add --no-cache ca-certificates

WORKDIR /app

COPY go.mod go.sum .
RUN go mod download

COPY . .

ARG TARGETARCH
RUN CGO_ENABLED=0 GOOS=linux GOARCH=${TARGETARCH} \
    go build -trimpath -ldflags="-s -w" -o /app/skillpulse .

# Stage 2: Run
FROM scratch

WORKDIR /app

COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=builder /app/skillpulse .

EXPOSE 8080

ENTRYPOINT ["/app/skillpulse"]
