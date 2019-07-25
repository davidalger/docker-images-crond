FROM centos:7

RUN yum install -y crontabs \
    && yum clean all \
    && rm -rf /var/cache/yum

# Disable pam_loginuid requirment for crond
RUN sed -i -e '/pam_loginuid.so/s/^/#/' /etc/pam.d/crond

CMD ["crond", "-n"]
