# Encoding: utf-8
require 'spec_helper'
require 'java_buildpack/container/jboss'
require 'java_buildpack/application'

module JavaBuildpack::Container

  describe Jboss do

    JBOSS_VERSION = JavaBuildpack::Util::TokenizedVersion.new('7.1.1')

    JBOSS_DETAILS = [JBOSS_VERSION, 'test-jboss-uri']

    let(:application_cache) { double('ApplicationCache') }

    before do
      $stdout = StringIO.new
      $stderr = StringIO.new
    end

    it 'should detect WEB-INF' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(JBOSS_VERSION) if block }
      .and_return(JBOSS_DETAILS)
      detected = Jboss.new(
          app_dir: 'spec/fixtures/container_tomcat',
          application: JavaBuildpack::Application.new('spec/fixtures/container_tomcat'),
          configuration: {}
      ).detect

      expect(detected).to include('jboss=7.1.1')
    end

    it 'should not detect when WEB-INF is absent' do
      detected = Jboss.new(
          app_dir: 'spec/fixtures/container_main',
          application: JavaBuildpack::Application.new('spec/fixtures/container_main'),
          configuration: {}
      ).detect

      expect(detected).to be_nil
    end

    it 'should extract JBoss from a GZipped TAR' do
      Dir.mktmpdir do |root|
        Dir.mkdir File.join(root, 'WEB-INF')

        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(JBOSS_VERSION) if block }
        .and_return(JBOSS_DETAILS)

        JavaBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-jboss-uri').and_yield(File.open('spec/fixtures/stub-jboss.tar.gz'))

        Jboss.new(
            app_dir: root,
            application: JavaBuildpack::Application.new(root),
            configuration: {}
        ).compile

        jboss_dir = File.join root, '.jboss'

        standalone = File.join jboss_dir, 'bin', 'standalone.sh'
        expect(File.exists?(standalone)).to be_true

      end
    end

    it 'should correctly manipulate the standalone configuration' do
      Dir.mktmpdir do |root|
        Dir.mkdir File.join(root, 'WEB-INF')

        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(JBOSS_VERSION) if block }
        .and_return(JBOSS_DETAILS)

        JavaBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-jboss-uri').and_yield(File.open('spec/fixtures/stub-jboss.tar.gz'))

        Jboss.new(
            app_dir: root,
            application: JavaBuildpack::Application.new(root),
            configuration: {}
        ).compile

        jboss_dir = File.join root, '.jboss'

        standalone = File.join jboss_dir, 'standalone', 'configuration', 'standalone.xml'
        expect(File.exists?(standalone)).to be_true
        File.open(standalone, 'r') do |f|
          standalone_content = f.read
          expect(standalone_content).to include('<socket-binding name="http" port="${http.port}"/>')
          expect(standalone_content).to include('<virtual-server name="default-host" enable-welcome-root="false">')
        end

      end
    end

    it 'should create a "ROOT.war.dodeploy" in the deployments directory' do
      Dir.mktmpdir do |root|
        Dir.mkdir File.join(root, 'WEB-INF')

        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(JBOSS_VERSION) if block }
        .and_return(JBOSS_DETAILS)

        JavaBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-jboss-uri').and_yield(File.open('spec/fixtures/stub-jboss.tar.gz'))

        Jboss.new(
            app_dir: root,
            application: JavaBuildpack::Application.new(root),
            configuration: {}
        ).compile

        dodeploy = File.join root, '.jboss', 'standalone', 'deployments', 'ROOT.war.dodeploy'
        expect(File.exists?(dodeploy)).to be_true

      end
    end

    it 'should link only the application files and directories to the ROOT webapp' do
      Dir.mktmpdir do |root|
        Dir.mkdir File.join(root, 'WEB-INF')
        FileUtils.touch File.join(root, 'index.html')

        JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(JBOSS_VERSION) if block }
        .and_return(JBOSS_DETAILS)

        JavaBuildpack::Util::ApplicationCache.stub(:new).and_return(application_cache)
        application_cache.stub(:get).with('test-jboss-uri').and_yield(File.open('spec/fixtures/stub-jboss.tar.gz'))

        application = JavaBuildpack::Application.new(root)

        FileUtils.touch File.join(root, '.test-file')

        Jboss.new(
            app_dir: root,
            application: application,
            configuration: {}
        ).compile

        root_webapp = File.join root, '.jboss', 'standalone', 'deployments', 'ROOT.war'

        web_inf = File.join root_webapp, 'WEB-INF'
        expect(File.exists?(web_inf)).to be_true
        #expect(File.readlink(web_inf)).to eq('../../../../WEB-INF')

        index = File.join root_webapp, 'index.html'
        expect(File.exists?(index)).to be_true
        #expect(File.readlink(index)).to eq('../../../../index.html')

        test_file = File.join root_webapp, '.test_file'
        expect(File.exists?(test_file)).to be_false
      end
    end

    it 'should return command' do
      JavaBuildpack::Repository::ConfiguredItem.stub(:find_item) { |&block| block.call(JBOSS_VERSION) if block }
      .and_return(JBOSS_DETAILS)

      command = Jboss.new(
          app_dir: 'spec/fixtures/container_tomcat',
          application: JavaBuildpack::Application.new('spec/fixtures/container_tomcat'),
          java_home: 'test-java-home',
          java_opts: %w(test-opt-2 test-opt-1),
          configuration: {}
      ).release

      expect(command).to eq('JAVA_HOME=test-java-home JAVA_OPTS="-Dhttp.port=$PORT test-opt-1 test-opt-2" .jboss/bin/standalone.sh -b 0.0.0.0')
    end

  end
end
