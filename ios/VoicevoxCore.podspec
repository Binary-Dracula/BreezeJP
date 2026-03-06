Pod::Spec.new do |s|
  s.name         = 'VoicevoxCore'
  s.version      = '0.16.4'
  s.summary      = 'VOICEVOX Core - 离线日语语音合成引擎'
  s.homepage     = 'https://github.com/VOICEVOX/voicevox_core'
  s.license      = { :type => 'MIT' }
  s.author       = 'VOICEVOX'
  s.source       = { :path => '.' }
  s.ios.deployment_target = '13.0'
  s.vendored_frameworks = 'voicevox_core.xcframework'
end
