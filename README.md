# Drone 安装及使用说明

## 部署

### 使用docker-compose安装在docker上

根据个人的情况，修改下面的参数，然后使用下面的docker-compose.yml就可以了。

对应的host需要能接受来自github的webhook

```yml
version: '2'
services:
  drone-server:
    image: drone/drone:1.0.0
    ports:
      - "127.0.0.1:8085:80"
    volumes:
      - /var/lib/drone:/data
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - DRONE_OPEN=true
      - DRONE_USER_CREATE=username:admin,admin:true
      - DRONE_SERVER_HOST=<your host>
      - DRONE_GITHUB_SERVER=https://github.com
      - DRONE_GITHUB_CLIENT_ID=<your GITHUB_CLIENT_ID>
      - DRONE_GITHUB_CLIENT_SECRET=<your GITHUB_CLIENT_SECRET>
      - DRONE_DEBUG=true
      - DRONE_GITHUB=true
      - DRONE_PROVIDER=github
      - DRONE_RPC_SECRET=<random strings 1>
  drone-agent:
    image: drone/agent:1.0.0
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    depends_on:
      - drone-server
    environment:
      - DRONE_RPC_SERVER=<your host>
      - DRONE_RPC_SECRET=<random strings 1>
      - DRONE_DEBUG=true
      - DOCKER_HOST=tcp://docker-bind:2375
  docker-bind:
     image: docker:dind
     privileged: true
     command: --storage-driver=overlay


```



### 使用 helm 安装在kubernetes上

从git上获取最新的charts到本地，然后修改values.yaml上对应的字段，主要是修改image的版本及sourceControl下的相关配置。

需提前装备好pv，以及将gitlab的clientSecretKey保存到对应的namespace下面的secret。

然后执行下面的命令

~~~sh
helm upgrade --install drone --namespace devops-cicd --debug . --dry-run
# 如更新了image tag不生效，可执行下面的语句
helm upgrade --install drone --namespace devops-cicd --debug . --dry-run --reset-values
~~~

>  kubernetes平台下面是使用server + scheduler/kube实现的，如需进行相应的修改，可以参考[官方源码](https://sourcegraph.com/github.com/drone/drone@2a3ffc7/-/blob/cmd/drone-server/inject_scheduler.go#L20:26)中的变量格式，然后注入到server下面的env中即可。

下面的为values.yml中的一些配置，仅作参考。

```yaml
images:
  ## The official drone (server) image, change tag to use a different version.
  ## ref: https://hub.docker.com/r/drone/drone/tags/
  ##
  server:
    repository: "docker.io/drone/drone"
    tag: 1.0.0
    pullPolicy: IfNotPresent

  ## The official drone (agent) image, change tag to use a different version.
  ## ref: https://hub.docker.com/r/drone/agent/tags/
  ##
  agent:
    repository: "docker.io/drone/agent"
    tag: 1.0.0
    pullPolicy: IfNotPresent

  ## The official docker (dind) image, change tag to use a different version.
  ## ref: https://hub.docker.com/r/library/docker/tags/
  ##
  dind:
    repository: "docker.io/library/docker"
    tag: 18.06.1-ce-dind
    pullPolicy: IfNotPresent

service:
  httpPort: 80

  ## If service.type is not set to NodePort, the following statement
  ## will be ignored.
  ##
  # nodePort: 32015
  nodePort: 32015

  ## Service type can be set to ClusterIP, NodePort or LoadBalancer.
  ##
  #type: ClusterIP
  type: NodePort

  ## Specify a load balancer IP address to use if your provider supports it.
  # loadBalancerIP:

  ## Drone Service annotations
  ##
  # annotations:
  #   service.beta.kubernetes.io/aws-load-balancer-backend-protocol: http
  #   service.beta.kubernetes.io/aws-load-balancer-ssl-cert: arn:aws:acm:xx-xxxx-x:xxxxxxxxxxx:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxx
  #   external-dns.alpha.kubernetes.io/hostname: drone.domain.tld.

  ## set to true if you want to expose drone's GRPC via the service (for external access)
  exposeGRPC: false

ingress:
  ## If true, Drone Ingress will be created.
  ##
  enabled: false

sourceControl:
  ## your source control provider: github,gitlab,gitea,gogs,bitbucketCloud,bitbucketServer
  provider:
    gitlab
  ## secret containing your source control provider secrets, keys provided below.
  ## if left blank will assume a secret based on the release name of the chart.
  secret:
  ## Fill in the correct values for your chosen source control provider
  ## Any key in this list with the suffix `Key` will be fetched from the
  ## secret named above, if not provided the secret will default to
  ## `<fullName>-source-control`
  github:
    clientID:
    clientSecretKey: clientSecret
    server: https://github.com
  gitlab:
    clientID: d4e6ead64e6f26219c9f9522bbf9d5a04d8e038110bd97834351fde75acc789a
    clientSecretKey: clientSecret 
    server: http://gitlab.foobar.com
  gitea:
    server:
  gogs:
    server:
  bitbucketCloud:
    clientID:
    clientSecret: clientSecret
  bitbucketServer:
    server:
    consumerKey: consumerKey
    privateKey: privateKey
    username:
    passwordKey: password

server:
  ## If not set, it will be autofilled with the cluster host.
  ## Host shoud be just the hostname.
  ##
  # host: "drone.domain.io"
  host: "10.0.60.26:32015"

  ## protocol should be http or https
  protocol: http

  ## Initial admin user
  ## Leaving this blank may make it impossible to log into drone.
  ## Set to a valid oauth user from your git/oauth server
  ## For more complex user creation you can use env variables below instead.
  adminUser:

  ## Configures Drone to authenticate when cloning public repositories. This is only required
  ## when your source code management system (e.g. GitHub Enterprise) has private mode enabled.
  #alwaysAuth: false

  ## Configures drone to use kubernetes to run pipelines rather than agents, if enabled
  ## will not deploy any agents.
  kubernetes:
    ## set to true if you want drone to use kubernetes to run pipelines
    enabled: true
    ## you can run pipeline jobs in another namespace, if you choose to do this
    ## you'll need to create that namespace manually.
   # namespace:
    ## alternative service account to create to create drone pipelines. this account
    ## will be given cluster-admin rights.
    ## if not set the rights will be given to the default drone service account name.
    # pipelineServiceAccount:

  ## Drone server configuration.
  ## Values in here get injected as environment variables.
  ## You can set up remote database servers etc using environment
  ## variables.
  ## ref: https://docs.drone.io/reference/server/
  ##
  env:
    DRONE_LOGS_DEBUG: "false"
    DRONE_DATABASE_DRIVER: "sqlite3"
    DRONE_DATABASE_DATASOURCE: "/var/lib/drone/drone.sqlite"
    DRONE_SECRET_SECRET: "1b8e384d9ce5b355501a326182e8ea45"
    DRONE_SECRET_ENDPOINT: "http://drone-kubernetes-secrets"
    DRONE_USER_CREATE: "username:jenkins,admin:true"
    #DRONE_RUNNER_IMAGE: "harbor.foobar.com/devops/drone-controller:1.0.0"
    DRONE_KUBERNETES_IMAGE: "harbor.foobar.com/devops/drone-controller:1.0.0"

  ## Secret environment variables are configured in `server.envSecrets`.
  ## Each item in `server.envSecrets` references a Kubernetes Secret.
  ## These Secrets should be created before they are referenced.
  ##
  # envSecrets:
  #   # The name of a Kubernetes Secret
  #   drone-server-secrets:
  #     # A list of Secret keys to include as environment variables
  #     - DRONE_GITHUB_SECRET

  ## Additional server annotations.
  ## ref: https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/
  ##
  annotations: {}

  ## CPU and memory limits for drone server
  ##
  resources: {}
  #  requests:
  #    memory: 32Mi
  #    cpu: 40m
  #  limits:
  #    memory: 2Gi
  #    cpu: 1

  ## Use an alternate scheduler, e.g. "stork".
  ## ref: https://kubernetes.io/docs/tasks/administer-cluster/configure-multiple-schedulers/
  ##
  # schedulerName:

  ## Pod scheduling preferences.
  ## ref: https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#affinity-and-anti-affinity
  ##
  affinity: {}

  ## Node labels for pod assignment
  ## ref: https://kubernetes.io/docs/user-guide/node-selection
  ##
  nodeSelector: {}

  ## additional siecar containers, e. g. for a database proxy, such as Google's cloudsql-proxy.
  ## ex: https://github.com/kubernetes/charts/tree/master/stable/keycloak
  ##
  extraContainers: |

  ## additional volumes, e. g. for secrets used in an extraContainers.
  ##
  extraVolumes: |

agent:
  ## Drone agent configuration.
  ## Values in here get injected as environment variables.
  ## ref: https://docs.drone.io/reference/agent/
  ##
  env:
    DRONE_LOGS_DEBUG: "false"

  ## Number of drone agent replicas
  replicas: 1

  ## Additional agent annotations.
  ## ref: https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/
  ##
  annotations: {}

  ## CPU and memory limits for drone agent
  ##
  resources: {}
  #  requests:
  #    memory: 32Mi
  #    cpu: 40m
  #  limits:
  #    memory: 2Gi
  #    cpu: 1

  ## Liveness and readiness probe values
  ## Ref: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#container-probes
  ## drone agent does not currently have a health endpoint to check against.
  livenessProbe: {}
  readinessProbe: {}

  ## Use an alternate scheduler, e.g. "stork".
  ## ref: https://kubernetes.io/docs/tasks/administer-cluster/configure-multiple-schedulers/
  ##
  # schedulerName:

  ## Pod scheduling preferences.
  ## ref: https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#affinity-and-anti-affinity
  ##
  affinity: {}

  ## Node labels for pod assignment
  ## ref: https://kubernetes.io/docs/user-guide/node-selection
  ##
  nodeSelector: {}

dind:
  ## Enable or disable DinD
  ## If disabled, the drone agent will spawn docker containers on the host. Pay
  ## attention to the fact that we can't enforce resource constraints in that case.
  ##
  enabled: true

  ## Values in here get injected as environment variables to DinD.
  ## ref: http://readme.drone.io/admin/installation-reference
  ##
  #  env:
  #    DRONE_DEBUG: "false"

  ## Allowing custom command and args to DinD
  ## ref: https://discourse.drone.io/t/docker-mtu-problem/1207
  ##
  #  command: '["/bin/sh"]'
  #  args: '["-c", "dockerd --host=unix:///var/run/docker.sock --host=tcp://127.0.0.1:2375 --mtu=1350"]'

  ## Docker storage driver.
  ## Your DinD instance should be using the same driver as your host.
  ## ref: https://docs.docker.com/engine/userguide/storagedriver/selectadriver/
  ##
  driver: overlay2

  ## CPU and memory limits for dind
  ##
  resources: {}
  #  requests:
  #    memory: 32Mi
  #    cpu: 40m
  #  limits:
  #    memory: 2Gi
  #    cpu: 1

## Enable scraping of the /metrics endpoint for Prometheus
metrics:
  prometheus:
    enabled: true

## Enable persistence using Persistent Volume Claims
## ref: http://kubernetes.io/docs/user-guide/persistent-volumes/
##
persistence:
  enabled: true

  ## A manually managed Persistent Volume and Claim
  ## Requires persistence.enabled: true
  ## If defined, PVC must be created manually before volume will be bound
  existingClaim: drone-pvc

  ## rabbitmq data Persistent Volume Storage Class
  ## If defined, storageClassName: <storageClass>
  ## If set to "-", storageClassName: "", which disables dynamic provisioning
  ## If undefined (the default) or set to null, no storageClassName spec is
  ##   set, choosing the default provisioner.  (gp2 on AWS, standard on
  ##   GKE, AWS & OpenStack)
  ##
  # storageClass: "-"
  accessMode: ReadWriteOnce
  size: 2Gi

## Uncomment this if you want to set a specific shared secret between
## the agents and servers, otherwise this will be auto-generated.
##
# sharedSecret: supersecret

rbac:
  ## Specifies whether RBAC resources should be created
  create: true
  ## RBAC api version (v1, v1beta1, or v1alpha1)
  apiVersion: v1

serviceAccount:
  ## Specifies whether a ServiceAccount should be created
  create: true
  ## The name of the ServiceAccount to use.
  ## If not set and create is true, a name is generated using the fullname template
  name:

```

到此基本已完成kubernetes下drone的安装。

## 使用drone/kubernetes-secrets插件

默认drone对应的secret是和repo进行绑定的，这样的话，每个repo都需要添加secret，而且后期变更也比较麻烦。这里我们将secret 保存在kubernetes里， 使用 drone/kubernetes-secrets 来读取对应的secret。[官方文档](https://docs.drone.io/extend/secrets/kubernetes/install/)下只有docker的安装方式，需要自己修改成kubernetes下的deployment。

安装完成后需要再drone-server下面添加

*DRONE_SECRET_SECRET* 和 *DRONE_SECRET_ENDPOINT*

具体参数可以参见[官网的源码](https://github.com/drone/drone-kubernetes-secrets) 以及[这篇讨论](https://discourse.drone.io/t/kubernetes-external-secrets-not-work/3546/6)

然后将drone的secret保存到对应的namespace下面的secret里。（需要进行base64加密）

![](https://ws1.sinaimg.cn/large/b77abccagy1g1mx4417vwj213g0h1t9r.jpg)

##  使用 .drone.yml

drone默认读取repo的根目录下**.drone.yml**

.drone.yml里保存对应的pipeline

默认的第一步是clone代码，然后build code，build and push image，最后面是用helm部署到kubernetes下面。

下面是我用到的yml，需要将对应的image地址换成官方的或者自己harbor的地址。

```yml
kind: pipeline
name: default


#clone:
#  depth: 50

# code build --> docker build and docker push --> deploy
# 使用drone，需要修改drone.yml和charts下面的values.yml
# 默认push到dev即会进行构建，在提交信息里加入 [CI SKIP] 即可跳过本次构建


steps:
  - name: backend
    image: harbor.foobar.com/devops/jenkins:jnlp-1.0.0
    commands:
      - mvn clean package -Dmaven.test.skip=true

  - name: publish
    image: plugins/docker
    settings:
      username:
        from_secret: dev_docker_username
      password:
        from_secret: dev_docker_password
      insecure: true
      repo: 127.0.0.1/cloud/${DRONE_REPO_NAME}
      registry: 127.0.0.1
      dockerfile: Dockerfile
      tags:
        - latest
        - "${DRONE_BRANCH}-${DRONE_COMMIT_SHA:0:7}"
    when:
      event: push
      branch: dev

  - name: publish_tag
    image: plugins/docker
    settings:
      username:
        from_secret: dev_docker_username
      password:
        from_secret: dev_docker_password
      insecure: true
      repo: 127.0.0.1/cloud/${DRONE_REPO_NAME}
      registry: 127.0.0.1
      dockerfile: Dockerfile
      tags:
        - "${DRONE_TAG##v}"
        - "${DRONE_BRANCH}-${DRONE_COMMIT_SHA:0:7}"
    when:
      event: tag
      branch: master

# namespace默认是foobar-cloud
  - name: helm_deploy
    image: harbor.foobar.com/devops/drone-helm
    environment:
      DEV_API_SERVER:
        from_secret: dev_api_server
      DEV_KUBERNETES_TOKEN:
        from_secret: dev_kubernetes_token
    settings:
      skip_tls_verify: true
      debug: true
      client_only: true
      stable_repo_url: https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts
      prefix: DEV
      chart: ./charts/app
      values: version=${DRONE_BRANCH}-${DRONE_COMMIT_SHA:0:7},image.tag=${DRONE_BRANCH}-${DRONE_COMMIT_SHA:0:7},image.repository=harbor.foobar.com/cloud/${DRONE_REPO_NAME}
      namespace: foobar-cloud
      release: "${DRONE_BRANCH}-${DRONE_REPO_NAME}"
    when:
      event: push
      branch: dev


# 以下的secret来自kubernetes对面的secret，通过上述的插件读取
---
kind: secret
name: dev_api_server
get:
  path: drone-k8s-secrets
  name: url

---
kind: secret
name: dev_kubernetes_token
get:
  path: drone-k8s-secrets
  name: token

---
kind: secret
name: dev_docker_username
get:
  path: drone-k8s-secrets
  name: username

---
kind: secret
name: dev_docker_password
get:
  path: drone-k8s-secrets
  name: password

```



## 使用helm插件

上面的最后一步就是利用helm插件，将对面的程序部署到kubernets中。

下面将介绍helm模板的一些使用，建议先[阅读官方的文档](http://plugins.drone.io/ipedrazas/drone-helm/)。

下面是我用到的yml，需要根据个人的情况进行更改。

`stable_repo_url`请保留，否者`helm init`将因为某些原因失败。

```yml
# namespace默认是foobar-cloud
  - name: helm_deploy
    image: harbor.foobar.com/devops/drone-helm
    environment:
      DEV_API_SERVER:
        from_secret: dev_api_server
      DEV_KUBERNETES_TOKEN:
        from_secret: dev_kubernetes_token
    settings:
      skip_tls_verify: true
      debug: true
      client_only: true
      stable_repo_url: https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts
      prefix: DEV
      chart: ./charts/app
      values: version=${DRONE_BRANCH}-${DRONE_COMMIT_SHA:0:7},image.tag=${DRONE_BRANCH}-${DRONE_COMMIT_SHA:0:7},image.repository=harbor.foobar.com/cloud/${DRONE_REPO_NAME}
      namespace: foobar-cloud
      release: "${DRONE_BRANCH}-${DRONE_REPO_NAME}"
    when:
      event: push
```



这个插件执行的内容为

```sh
helm init
helm upgrade --install RELEASE CHART
```

settings下面values部分就是替换chart下面values.yml中的变量。

部署完成后，我们可以helm更方便的进行管理drone部署的程序，可以进行回滚和更新。



> 相关代码存放在[github](https://github.com/zou2699/drone-demo)