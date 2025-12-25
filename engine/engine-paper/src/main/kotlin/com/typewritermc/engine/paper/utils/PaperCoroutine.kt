package com.typewritermc.engine.paper.utils

import com.github.shynixn.mccoroutine.folia.asyncDispatcher
import com.github.shynixn.mccoroutine.folia.globalRegionDispatcher
import com.typewritermc.core.utils.TypewriterDispatcher
import com.typewritermc.engine.paper.plugin
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers

private object PaperTickedAsyncDispatcher : TypewriterDispatcher(plugin.asyncDispatcher)
private object PaperSyncDispatcher : TypewriterDispatcher(plugin.globalRegionDispatcher)

val Dispatchers.Sync: CoroutineDispatcher get() = PaperSyncDispatcher
val Dispatchers.TickedAsync: CoroutineDispatcher get() = PaperTickedAsyncDispatcher

