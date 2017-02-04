FROM alpine:3.5

# Set up an Alpine Linux machine running an SSH server.
# Autogenerate missing host keys.

RUN apk add --no-cache openssh
RUN ssh-keygen -A

# Create the skeleton directory, used for creating new users.

RUN mkdir -p /etc/skel/.ssh
RUN chmod 700 /etc/skel/.ssh

RUN touch /etc/skel/.ssh/authorized_keys
RUN chmod 600 /etc/skel/.ssh/authorized_keys

# Run SSH daemon and expose the standard SSH port.

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]

# For debugging, let sshd be more verbose:
# CMD ["/usr/sbin/sshd", "-D", "-d", "-d", "-d"]
