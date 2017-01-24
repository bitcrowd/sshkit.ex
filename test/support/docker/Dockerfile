FROM alpine:3.5

# Set up an Alpine Linux machine running an SSH server.
# Autogenerate missing host keys.

RUN apk add --no-cache openssh
RUN ssh-keygen -A

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]

# For debugging, let sshd be more verbose:
# CMD ["/usr/sbin/sshd", "-D", "-d", "-d", "-d"]
