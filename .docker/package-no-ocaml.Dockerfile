# This Dockerfile should be run from the root FStar directory
# It builds and tests a binary package for F*.
# It is a potential alternative to .scripts/process_build.sh

# Build the package
ARG ocaml_version=4.12
ARG opamthreads=24

FROM ocaml/opam:ubuntu-20.04-ocaml-$ocaml_version AS fstardep

# FIXME: the `opam depext` command should be unnecessary with opam 2.1
RUN opam depext conf-gmp z3.4.8.5 conf-m4

ADD --chown=opam:opam ./fstar.opam fstar.opam

# Install opam dependencies only
RUN opam install --deps-only ./fstar.opam

FROM fstardep AS fstarbuild
ADD --chown=opam:opam ./ FStar/

# Build the package, 
RUN eval $(opam env) && env Z3_LICENSE="$(opam config expand '%{prefix}%')/.opam-switch/sources/z3.4.8.5/LICENSE.txt" OTHERFLAGS='--admit_smt_queries true' make -C FStar -j $opamthreads package_unknown_platform

# Create a separate image to test the package
FROM fstardep AS fstarbin

# Copy the F* binary package
COPY --from=fstarbuild /home/opam/FStar/src/ocaml-output/fstar.tar.gz /home/opam/fstar.tar.gz
RUN tar xzf fstar.tar.gz
ENV PATH="/home/opam/fstar/bin:${PATH}"

# Copy examples and docs
ADD --chown=opam:opam examples/ fstar_examples/
ADD --chown=opam:opam doc/ fstar_doc/

# Test the F* binary package

# Test the fresh package without OCaml
FROM ubuntu:20.04 AS fstarnoocaml
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update
RUN apt-get --yes install --no-install-recommends make sudo libgomp1

# Create a new user and give them sudo rights
RUN useradd -d /home/test test
RUN echo 'test ALL=NOPASSWD: ALL' >> /etc/sudoers
RUN mkdir /home/test
RUN chown test:test /home/test
USER test
ENV HOME /home/test
WORKDIR $HOME
SHELL ["/bin/bash", "--login", "-c"]

# Copy the package
COPY --from=fstarbuild /home/opam/FStar/src/ocaml-output/fstar.tar.gz /home/test/fstar.tar.gz
RUN tar xzf fstar.tar.gz
ENV PATH="/home/test/fstar/bin:${PATH}"

# Copy tests, examples and docs
ADD --chown=test:test examples/ fstar_examples/
ADD --chown=test:test doc/ fstar_doc/

# Case 3: test F* package without OCaml
FROM fstarnoocaml
RUN make -C fstar_examples -j $opamthreads
RUN make -C fstar_doc/tutorial -j $opamthreads regressions

# This is the last image. So we can also copy the file that contains
# the desired filename for the package, to be extracted via
# `docker cp`
COPY --from=fstarbuild /home/opam/FStar/src/ocaml-output/version_platform.txt /home/test/version_platform.txt
