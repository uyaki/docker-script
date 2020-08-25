```
docker run --rm -t -i -v /srv/gitlab-runner/config:/etc/gitlab-runner gitlab/gitlab-runner register \
 --non-interactive \
 --executor "docker" \
 --docker-image alpine:3 \
 --url "http://xxxx/" \
 --registration-token "xxxxxxx" \
 --description "gitlab-runner-gkd" \
 --tag-list "maven,docker,gkd" \
 --run-untagged \
 --locked="false"
```