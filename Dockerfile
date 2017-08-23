FROM concourse/buildroot:ruby

ADD deps /tmp/deps

RUN gem install /tmp/deps/*.gem --no-document

ADD . /tmp/resource-gem

RUN cd /tmp/resource-gem && \
    gem build *.gemspec && gem install *.gem --no-document && \
    mkdir -p /opt/resource && \
    ln -s $(which pcr_check) /opt/resource/check && \
    ln -s $(which pcr_in) /opt/resource/in && \
    ln -s $(which pcr_out) /opt/resource/out