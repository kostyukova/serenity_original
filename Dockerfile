# Use latest jboss/base-jdk:8 image as the base
#FROM jboss/base-jdk:8
FROM openjdk:8-jdk

# Set the WILDFLY_VERSION env variable
ENV WILDFLY_VERSION 10.1.0.Final
ENV WILDFLY_SHA1 9ee3c0255e2e6007d502223916cefad2a1a5e333
ENV JBOSS_HOME /opt/jboss/wildfly

# Create a user and group used to launch processes
# The user ID 1000 is the default for the first "regular" user on Fedora/RHEL,
# so there is a high chance that this ID will be equal to the current user
# making it easier to use volumes (no permission issues)
RUN groupadd -r jboss -g 1000 && useradd -u 1000 -r -g jboss -m -d /opt/jboss -s /sbin/nologin -c "JBoss user" jboss && \
    chmod 755 /opt/jboss

# Set the working directory to jboss' user home directory
WORKDIR /opt/jboss

USER root

# Add the WildFly distribution to /opt, and make wildfly the owner of the extracted tar content
# Make sure the distribution is available from a well-known place
RUN curl -O https://download.jboss.org/wildfly/$WILDFLY_VERSION/wildfly-$WILDFLY_VERSION.tar.gz \
    && sha1sum wildfly-$WILDFLY_VERSION.tar.gz | grep $WILDFLY_SHA1 \
    && tar xf wildfly-$WILDFLY_VERSION.tar.gz \
    && mv wildfly-$WILDFLY_VERSION $JBOSS_HOME \
    && rm wildfly-$WILDFLY_VERSION.tar.gz

RUN ls -l $JBOSS_HOME \    
    && chown -R jboss ${JBOSS_HOME} \
    && chmod -R g+rw ${JBOSS_HOME}

# Ensure signals are forwarded to the JVM process correctly for graceful shutdown
ENV LAUNCH_JBOSS_IN_BACKGROUND true

# Install phantomjs (is used by WTP )
RUN set -x \
	&& apt-get update \
	&& apt-get -y install phantomjs

# start elastic service 1.7.3
# curl -XGET 172.17.0.2:9200
ADD elasticsearch/elasticsearch-1.7.3.deb ./
RUN dpkg -i elasticsearch-1.7.3.deb
ADD elasticsearch/elasticsearch.yml /etc/elasticsearch/

# wildfly modules
ADD brandmaker /opt/brandmaker
ADD microsoft  /opt/jboss/wildfly/modules/system/layers/base/com
ADD mysql      /opt/jboss/wildfly/modules/system/layers/base/com
ADD picketlink /opt/jboss/wildfly/modules/system/layers/base/org

ADD standalone.conf /opt/jboss/wildfly/bin
ADD standalone-full_serenity.xml /opt/jboss/wildfly/standalone/configuration

# deployments
ADD deployments/*.ear /opt/jboss/wildfly/standalone/deployments/
ADD deployments/*.war /opt/jboss/wildfly/standalone/deployments/

RUN ls -l $JBOSS_HOME \    
    && chown -R jboss:jboss ${JBOSS_HOME} \
    && chmod -R 777 ${JBOSS_HOME}

RUN ls -l $JBOSS_HOME \
    && ls -l /opt/jboss/wildfly/standalone/deployments

USER jboss
# Expose the ports we're interested in
EXPOSE 8080

RUN ls -l /opt/jboss/wildfly/standalone/deployments

# Set the default command to run on boot
# This will boot WildFly in the standalone mode and bind to all interface
CMD service elasticsearch start && /opt/jboss/wildfly/bin/standalone.sh -b 0.0.0.0 -c standalone-full_serenity.xml
