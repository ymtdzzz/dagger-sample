FROM golang:1.18-alpine

WORKDIR /app

COPY ./src/go.mod .
COPY ./src/go.sum .
RUN go mod download

COPY ./src/*.go .

RUN go build -o /sample-app

EXPOSE 8080

CMD [ "/sample-app" ]
