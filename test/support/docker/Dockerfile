FROM debian:jessie

# Set up a Debian machine running an SSH server,
# a test user with authorized keys.

RUN apt-get update && apt-get install -y openssh-server && rm -rf /var/lib/apt/lists/*
RUN mkdir /var/run/sshd

RUN useradd --user-group --create-home test
RUN echo 'test:test' | chpasswd

ENV SSHDIR /home/test

RUN mkdir -p $SSHDIR/.ssh

COPY pub.key $SSHDIR/.ssh/authorized_keys

RUN chown -R test:test $SSHDIR/.ssh
RUN chmod -R go-rwx $SSHDIR/.ssh/authorized_keys

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]

# For debugging, let sshd be more verbose:
# CMD ["/usr/sbin/sshd", "-D", "-d", "-d", "-d"]
