# fsearch-docker
构建命令docker build -t fsearch-web:slim .

启动容器
docker run -d \
  --name fsearch \
  -p 8081:8080 \
  -v /home/:/home/ \
  /fsearch-web:slim
