require 'spec_helper'

describe 'nova::metadata::novajoin::api' do

  let :facts do
    @default_facts.merge(
      {
        :osfamily               => 'RedHat',
        :processorcount         => '7',
        :fqdn                   => "undercloud.example.com",
        :operatingsystemrelease => '7.0',
      }
    )
  end

  let :default_params do
    {
      :bind_address              => '127.0.0.1',
      :api_paste_config          => '/etc/novajoin/join-api-paste.ini',
      :auth_strategy             => '<SERVICE DEFAULT>',
      :auth_type                 => 'password',
      :cacert                    => '/etc/ipa/ca.crt',
      :connect_retries           => '<SERVICE DEFAULT>',
      :debug                     => '<SERVICE DEFAULT>',
      :enabled                   => true,
      :enable_ipa_client_install => true,
      :ensure_package            => 'present',
      :join_listen_port          => '<SERVICE DEFAULT>',
      :keytab                    => '/etc/novajoin/krb5.keytab',
      :log_dir                   => '/var/log/novajoin',
      :manage_service            => true,
      :service_user              => 'novajoin',
      :project_domain_name       => 'default',
      :project_name              => 'service',
      :user_domain_id            => 'default',
      :ipa_domain                => 'EXAMPLE.COM',
      :keystone_auth_url         => 'https://keystone.example.com:35357',
      :service_password          => 'my_secret_password',
      :transport_url             => 'rabbit:rabbit_pass@rabbit_host',
    }
  end

  [{},
   {
      :bind_address              => '0.0.0.0',
      :api_paste_config          => '/etc/novajoin/join-api-paste.ini',
      :auth_strategy             => 'noauth2',
      :auth_type                 => 'password',
      :cacert                    => '/etc/ipa/ca.crt',
      :connect_retries           => 2,
      :debug                     => true,
      :enabled                   => false,
      :enable_ipa_client_install => false,
      :ensure_package            => 'present',
      :join_listen_port          => '9921',
      :keytab                    => '/etc/krb5.conf',
      :log_dir                   => '/var/log/novajoin',
      :manage_service            => true,
      :service_user              => 'novajoin1',
      :project_domain_name       => 'default',
      :project_name              => 'service',
      :user_domain_id            => 'default',
      :ipa_domain                => 'EXAMPLE2.COM',
      :keystone_auth_url         => 'https://keystone2.example.com:35357',
      :service_password          => 'my_secret_password2',
      :transport_url             => 'rabbit:rabbit_pass2@rabbit_host',
    }
  ].each do |param_set|

    describe "when #{param_set == {} ? "using default" : "specifying"} class parameters" do

      let :param_hash do
        default_params.merge(param_set)
      end

      let :params do
        param_hash
      end

      let :pre_condition do
        "class { '::ipaclient':
           password => 'join_otp'
         }
         class { '::nova::metadata::novajoin::authtoken':
           password => 'passw0rd',
         }
        "
      end

      it { is_expected.to contain_class('nova::metadata::novajoin::authtoken') }

      it { is_expected.to contain_service('novajoin-server').with(
        'ensure'     => (param_hash[:manage_service] && param_hash[:enabled]) ? 'running': 'stopped',
        'enable'     => param_hash[:enabled],
        'hasstatus'  => true,
        'hasrestart' => true,
        'tag'        => 'openstack',
      ) }

      it { is_expected.to contain_service('novajoin-notify').with(
        'ensure'     => (param_hash[:manage_service] && param_hash[:enabled]) ? 'running': 'stopped',
        'enable'     => param_hash[:enabled],
        'hasstatus'  => true,
        'hasrestart' => true,
        'tag'        => 'openstack',
      ) }

      it 'is_expected.to configure default parameters' do
        is_expected.to contain_novajoin_config('DEFAULT/join_listen').with_value(param_hash[:bind_address])
        is_expected.to contain_novajoin_config('DEFAULT/api_paste_config').with_value(param_hash[:api_paste_config])
        is_expected.to contain_novajoin_config('DEFAULT/auth_strategy').with_value(param_hash[:auth_strategy])
        is_expected.to contain_novajoin_config('DEFAULT/cacert').with_value(param_hash[:cacert])
        is_expected.to contain_novajoin_config('DEFAULT/connect_retries').with_value(param_hash[:connect_retries])
        is_expected.to contain_novajoin_config('DEFAULT/debug').with_value(param_hash[:debug])
        is_expected.to contain_novajoin_config('DEFAULT/join_listen_port').with_value(param_hash[:join_listen_port])
        is_expected.to contain_novajoin_config('DEFAULT/keytab').with_value(param_hash[:keytab])
        is_expected.to contain_novajoin_config('DEFAULT/log_dir').with_value(param_hash[:log_dir])
        is_expected.to contain_novajoin_config('DEFAULT/domain').with_value(param_hash[:ipa_domain])
        is_expected.to contain_novajoin_config('DEFAULT/transport_url').with_value(param_hash[:transport_url])
      end

      it 'is_expected.to configure service credentials' do
        is_expected.to contain_novajoin_config('service_credentials/auth_type').with_value(param_hash[:auth_type])
        is_expected.to contain_novajoin_config('service_credentials/auth_url').with_value(param_hash[:keystone_auth_url])
        is_expected.to contain_novajoin_config('service_credentials/password').with_value(param_hash[:service_password])
        is_expected.to contain_novajoin_config('service_credentials/project_name').with_value(param_hash[:project_name])
        is_expected.to contain_novajoin_config('service_credentials/user_domain_id').with_value(param_hash[:user_domain_id])
        is_expected.to contain_novajoin_config('service_credentials/project_domain_name').with_value(param_hash[:project_domain_name])
        is_expected.to contain_novajoin_config('service_credentials/username').with_value(param_hash[:service_user])
      end

      it 'is_expected.to get service user keytab' do
        is_expected.to contain_exec('get-service-user-keytab').with(
          'command' => "/usr/bin/kinit -kt /etc/krb5.keytab && ipa-getkeytab -s `grep xmlrpc_uri /etc/ipa/default.conf  | cut -d/ -f3` \
                -p nova/undercloud.example.com -k #{param_hash[:keytab]}",
        )
      end

      it { is_expected.to contain_file("#{param_hash[:keytab]}").with(
        'owner'   => "#{param_hash[:service_user]}",
        'require' => 'Exec[get-service-user-keytab]',
      )}

    end
  end

  describe 'with disabled service managing' do
    let :facts do
      OSDefaults.get_facts({
        :osfamily               => 'RedHat',
        :operatingsystem        => 'RedHat',
        :operatingsystemrelease => '7.0',
      })
    end

    let :params do
      {
        :manage_service    => false,
        :enabled           => false,
        :ipa_domain        => 'EXAMPLE.COM',
        :service_password  => 'my_secret_password',
        :transport_url     => 'rabbit:rabbit_pass@rabbit_host',
      }
    end

    let :pre_condition do
      "class { '::ipaclient': password => 'join_otp', }
       class { '::nova::metadata::novajoin::authtoken':
         password => 'passw0rd',
       }"
    end

    it { is_expected.to contain_service('novajoin-server').with(
        'ensure'     => nil,
        'enable'     => false,
        'hasstatus'  => true,
        'hasrestart' => true,
        'tag'        => 'openstack',
      ) }

    it { is_expected.to contain_service('novajoin-notify').with(
        'ensure'     => nil,
        'enable'     => false,
        'hasstatus'  => true,
        'hasrestart' => true,
        'tag'        => 'openstack',
      ) }
  end

  describe 'on RedHat platforms' do
    let :facts do
      OSDefaults.get_facts({
        :osfamily               => 'RedHat',
        :operatingsystem        => 'RedHat',
        :operatingsystemrelease => '7.0',
      })
    end
    let(:params) { default_params }

    let :pre_condition do
      "class { '::ipaclient': password => 'join_otp', }
       class { '::nova::metadata::novajoin::authtoken':
         password => 'passw0rd',
       }"
    end

    it { is_expected.to contain_package('python-novajoin').with(
        :tag => ['openstack', 'novajoin-package'],
    )}
  end
end
