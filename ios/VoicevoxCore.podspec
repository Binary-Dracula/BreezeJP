Pod::Spec.new do |s|
  s.name         = 'VoicevoxCore'
  s.version      = '0.16.4'
  s.summary      = 'VOICEVOX Core - 离线日语语音合成引擎'
  s.homepage     = 'https://github.com/VOICEVOX/voicevox_core'
  s.license      = { :type => 'MIT' }
  s.author       = 'VOICEVOX'
  s.source       = { :path => '.' }
  s.ios.deployment_target = '13.0'
  # voicevox_core.framework 链接 @rpath/voicevox_onnxruntime.framework/voicevox_onnxruntime
  # Runner.debug.dylib 链接 @rpath/onnxruntime.framework/onnxruntime
  # 两者 Bundle ID 不同，不会冲突
  s.vendored_frameworks = 'voicevox_core.xcframework',
                          'voicevox_onnxruntime.xcframework',
                          'onnxruntime.xcframework'
end
