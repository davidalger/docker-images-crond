FROM centos:7

RUN yum install -y crontabs \
    && yum clean all \
    && rm -rf /var/cache/yum

CMD ["crond", "-n"]
