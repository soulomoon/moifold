{-# LANGUAGE OverloadedRecordDot #-}

module CodexWatcher.CompatibilityRuntime
  ( writeCompatibility
  ) where

import CodexWatcher.CompatibilityState
import CodexWatcher.Runtime

writeCompatibility :: RuntimeInterpreter IO -> CompatibilityWrite -> IO ()
writeCompatibility interpreter write =
  interpreter.runtimeWriteJsonValue write.compatibilityWritePath write.compatibilityWriteValue
