package main

import (
  "dagger.io/dagger"
  "dagger.io/dagger/core"
  "universe.dagger.io/docker"
  "universe.dagger.io/docker/cli"
  "universe.dagger.io/go"
  "universe.dagger.io/aws"
)

dagger.#Plan & {
  client: {
    env: {
      ECR_REPOSITORY: string
      AWS_ACCESS_KEY_ID: dagger.#Secret
      AWS_SECRET_ACCESS_KEY: dagger.#Secret
    }
    filesystem: {
      ".": read: contents: dagger.#FS
      "./src": read: contents: dagger.#FS
    }
    network: "unix:///var/run/docker.sock": connect: dagger.#Socket
  }

  _sourceMount: "source code": {
    dest: "/src"
    type: "fs"
    contents: client.filesystem.".".read.contents
  }

  actions: {
    params: tag?: string

    _repository: "\(client.env.ECR_REPOSITORY):\(params.tag)"

    test: go.#Test & {
      source: client.filesystem."./src".read.contents
      package: "./..."
    }

    pushToECR: {
      loginAndPush: docker.#Build & {
        steps: [
          aws.#Container & {
            credentials: aws.#Credentials & {
              accessKeyId:     client.env.AWS_ACCESS_KEY_ID
              secretAccessKey: client.env.AWS_SECRET_ACCESS_KEY
            }
            command: {
              name: "sh"
              flags: "-c": "aws --region ap-northeast-1 ecr get-login-password | docker login --username AWS --password-stdin \(_repository)"
            }
            _build: _scripts: core.#Source & {
              path: "_scripts"
            }
          },
          cli.#Run & {
            host: client.network."unix:///var/run/docker.sock".connect
            workdir: "/src"
            mounts: _sourceMount
            command: {
              name: "docker"
              args: ["build", "-t", _repository, "."]
            }
          },
          cli.#Run & {
            host: client.network."unix:///var/run/docker.sock".connect
            command: {
              name: "docker"
              args: ["push", _repository]
            }
          }
        ]
      }
    }
  }
}
