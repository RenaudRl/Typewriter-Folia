package com.typewritermc.engine.paper.interaction

import com.github.shynixn.mccoroutine.folia.entityDispatcher
import com.github.shynixn.mccoroutine.folia.globalRegionDispatcher
import com.github.shynixn.mccoroutine.folia.registerSuspendingEvents
import com.typewritermc.core.interaction.*
import com.typewritermc.engine.paper.entry.entries.EventTrigger
import com.typewritermc.engine.paper.entry.entries.InteractionEndTrigger
import com.typewritermc.engine.paper.entry.triggerFor
import com.typewritermc.engine.paper.plugin
import kotlin.coroutines.CoroutineContext
import lirand.api.extensions.events.unregister
import com.typewritermc.engine.paper.utils.server
import org.bukkit.entity.Player
import org.bukkit.event.Cancellable
import org.bukkit.event.Event
import org.bukkit.event.Listener
import org.bukkit.event.entity.EntityDamageByBlockEvent
import org.bukkit.event.entity.EntityDamageByEntityEvent
import org.bukkit.event.entity.EntityDamageEvent
import org.bukkit.event.entity.PlayerDeathEvent
import org.bukkit.event.player.PlayerCommandPreprocessEvent
import org.bukkit.event.player.PlayerEvent
import org.bukkit.event.player.PlayerMoveEvent
import org.bukkit.event.player.PlayerTeleportEvent
import java.util.*

val Player.boundState: InteractionBoundState
    get() = interactionScope?.boundState ?: InteractionBoundState.IGNORING

suspend fun Player.overrideBoundState(
    state: InteractionBoundState,
    priority: Int = 0
): InteractionBoundStateOverrideSubscription {
    val id = interactionScope?.addBoundStateOverride(state = state, priority = priority) ?: UUID.randomUUID()
    return InteractionBoundStateOverrideSubscription(id, uniqueId)
}

suspend fun InteractionBoundStateOverrideSubscription.cancel() {
    server.getPlayer(playerUUID)?.interactionScope?.removeBoundStateOverride(id)
}

fun Player.interruptInteraction(context: InteractionContext? = interactionContext) {
    val interruptionTriggers =
        (interactionScope?.bound as? ListenerInteractionBound)?.interruptionTriggers ?: emptyList()
    (interruptionTriggers + InteractionEndTrigger + InteractionBoundEndTrigger).triggerFor(this, context ?: context())
}

private fun createPlayerEventDispatcherMap(): Map<Class<out Event>, (Event) -> CoroutineContext> {
    return mapOf(
        PlayerMoveEvent::class.java to { event -> plugin.entityDispatcher((event as PlayerMoveEvent).player) },
        PlayerTeleportEvent::class.java to { event -> plugin.entityDispatcher((event as PlayerTeleportEvent).player) },
        PlayerCommandPreprocessEvent::class.java to { event -> plugin.entityDispatcher((event as PlayerCommandPreprocessEvent).player) },
        EntityDamageEvent::class.java to { event ->
            val entity = (event as EntityDamageEvent).entity
            if (entity is Player) plugin.entityDispatcher(entity) else plugin.globalRegionDispatcher
        },
        EntityDamageByEntityEvent::class.java to { event ->
            val entity = (event as EntityDamageByEntityEvent).entity
            if (entity is Player) plugin.entityDispatcher(entity) else plugin.globalRegionDispatcher
        },
        EntityDamageByBlockEvent::class.java to { event ->
            val entity = (event as EntityDamageByBlockEvent).entity
            if (entity is Player) plugin.entityDispatcher(entity) else plugin.globalRegionDispatcher
        },
        PlayerDeathEvent::class.java to { event -> plugin.entityDispatcher((event as PlayerDeathEvent).player) }
    )
}

interface ListenerInteractionBound : InteractionBound, Listener {
    val interruptionTriggers: List<EventTrigger>

    override suspend fun initialize() {
        super.initialize()
        server.pluginManager.registerSuspendingEvents(this, plugin, createPlayerEventDispatcherMap())
    }

    override suspend fun teardown() {
        super.teardown()
        unregister()
    }

    fun <T> handleEvent(event: T) where T : PlayerEvent, T : Cancellable {
        when (event.player.boundState) {
            InteractionBoundState.BLOCKING -> event.isCancelled = true
            InteractionBoundState.INTERRUPTING -> event.player.interruptInteraction()
            InteractionBoundState.IGNORING -> {}
        }
    }
}