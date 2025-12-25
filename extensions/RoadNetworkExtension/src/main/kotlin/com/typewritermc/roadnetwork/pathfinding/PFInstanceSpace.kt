package com.typewritermc.roadnetwork.pathfinding

import com.typewritermc.roadnetwork.pathfinding.PFColumnarSpace
import com.destroystokyo.paper.event.block.BlockDestroyEvent
import com.extollit.gaming.ai.path.model.ColumnarOcclusionFieldList
import com.extollit.gaming.ai.path.model.IBlockDescription
import com.extollit.gaming.ai.path.model.IBlockObject
import com.extollit.gaming.ai.path.model.IColumnarSpace
import com.extollit.gaming.ai.path.model.IInstanceSpace
import com.extollit.linalg.immutable.AxisAlignedBBox
import com.typewritermc.core.extension.Initializable
import com.typewritermc.core.extension.annotations.Singleton
import com.typewritermc.core.utils.UntickedAsync
import com.typewritermc.core.utils.launch
import com.typewritermc.engine.paper.plugin
import com.typewritermc.engine.paper.utils.server
import com.typewritermc.engine.paper.utils.toBukkitWorld
import com.typewritermc.engine.paper.utils.toWorld
import io.papermc.paper.threadedregions.scheduler.ScheduledTask
import it.unimi.dsi.fastutil.longs.Long2ObjectOpenHashMap
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import org.bukkit.Bukkit
import lirand.api.extensions.events.unregister
import org.bukkit.World
import org.bukkit.event.EventHandler
import org.bukkit.event.EventPriority
import org.bukkit.event.Listener
import org.bukkit.event.block.*
import org.koin.java.KoinJavaComponent
import java.util.*
import java.util.concurrent.ConcurrentHashMap

class PFInstanceSpace(val world: com.typewritermc.core.utils.point.World) : IInstanceSpace {
    private val chunkSpaces = Long2ObjectOpenHashMap<PFColumnarSpace>()
    private var lastAccess = System.currentTimeMillis()

    override fun blockObjectAt(x: Int, y: Int, z: Int): IBlockObject {
        val chunkX = x shr 4
        val chunkZ = z shr 4

        val columnarSpace = columnarSpaceAt(chunkX, chunkZ)
        val relativeX = x and 15
        val relativeY = y and 15
        val relativeZ = z and 15
        return columnarSpace.blockAt(relativeX, relativeY, relativeZ) as IBlockObject
    }

    fun refresh(): Boolean {
        synchronized(chunkSpaces) {
            chunkSpaces.values.retainAll { it.refresh() }
        }
        return System.currentTimeMillis() - lastAccess < 1000 * 60 * 2
    }

    fun clear() {
        synchronized(chunkSpaces) {
            chunkSpaces.clear()
        }
    }

    fun evict(cx: Int, cz: Int) {
        val key = chunkKey(cx, cz)
        synchronized(chunkSpaces) {
            chunkSpaces.remove(key)
        }
    }

    suspend fun columnarSpaceAtAsync(cx: Int, cz: Int): IColumnarSpace {
        lastAccess = System.currentTimeMillis()
        val key = chunkKey(cx, cz)

        synchronized(chunkSpaces) {
            chunkSpaces[key]?.let { return it }
        }


        val bukkitWorld = world.toBukkitWorld()
        val snapshot = suspendCancellableCoroutine<org.bukkit.ChunkSnapshot> { cont ->
            var task: ScheduledTask? = null
            task = Bukkit.getRegionScheduler().run(plugin, bukkitWorld, cx, cz) { _ ->
                val chunk = bukkitWorld.getChunkAt(cx, cz)
                val chunkSnapshot = chunk.getChunkSnapshot(false, false, false)
                cont.resume(chunkSnapshot, null)
            }
            cont.invokeOnCancellation {
                task?.cancel()
            }
        }
        val space = PFColumnarSpace(world, snapshot, this)

        synchronized(chunkSpaces) {
            chunkSpaces[key] = space
        }
        return space
    }

    override fun columnarSpaceAt(cx: Int, cz: Int): IColumnarSpace {
        lastAccess = System.currentTimeMillis()
        val key = chunkKey(cx, cz)

        synchronized(chunkSpaces) {
            val space = chunkSpaces[key]
            if (space == null) {

                return UnloadedColumnarSpace(this)
            }
            return space
        }
    }
}

private class UnloadedColumnarSpace(private val instance: IInstanceSpace) : IColumnarSpace {
    private val occlusionFieldList = ColumnarOcclusionFieldList(this)

    override fun blockAt(x: Int, y: Int, z: Int): IBlockObject = UnloadedBlockObject
    override fun metaDataAt(x: Int, y: Int, z: Int): Int = 0
    override fun occlusionFields() = occlusionFieldList
    override fun instance() = instance
}

private object UnloadedBlockObject : IBlockObject, IBlockDescription {
    override fun bounds(): AxisAlignedBBox = AxisAlignedBBox(0.0, 0.0, 0.0, 1.0, 1.0, 1.0)
    override fun isFenceLike() = false
    override fun isClimbable() = false
    override fun isDoor() = false
    override fun isIntractable() = false
    override fun isImpeding() = true
    override fun isFullyBounded() = true
    override fun isLiquid() = false
    override fun isIncinerating() = false
}

@Singleton
class InstanceSpaceCache : Initializable, Listener {
    private val cache = ConcurrentHashMap<UUID, PFInstanceSpace>()
    private var job: Job? = null

    fun instanceSpace(world: World): PFInstanceSpace {
        return cache.computeIfAbsent(world.uid) { PFInstanceSpace(world.toWorld()) }
    }

    fun instanceSpace(world: com.typewritermc.core.utils.point.World): PFInstanceSpace {
        return cache.computeIfAbsent(UUID.fromString(world.identifier)) { PFInstanceSpace(world) }
    }

    override suspend fun initialize() {
        job = Dispatchers.UntickedAsync.launch {
            while (true) {
                delay(5000)
                cache.values.retainAll { it.refresh() }
            }
        }
        server.pluginManager.registerEvents(this, plugin)
    }

    fun clear() {
        cache.clear()
    }

    @EventHandler(priority = EventPriority.MONITOR, ignoreCancelled = true)
    fun onBlock(event: BlockPlaceEvent) = onBlockEvent(event)

    @EventHandler(priority = EventPriority.MONITOR, ignoreCancelled = true)
    fun onBlock(event: BlockBreakEvent) = onBlockEvent(event)

    @EventHandler(priority = EventPriority.MONITOR, ignoreCancelled = true)
    fun onBlock(event: BlockMultiPlaceEvent) = onBlockEvent(event)

    @EventHandler(priority = EventPriority.MONITOR, ignoreCancelled = true)
    fun onBlock(event: BlockPhysicsEvent) = onBlockEvent(event)

    @EventHandler(priority = EventPriority.MONITOR, ignoreCancelled = true)
    fun onBlock(event: BlockBurnEvent) = onBlockEvent(event)

    @EventHandler(priority = EventPriority.MONITOR, ignoreCancelled = true)
    fun onBlock(event: BlockExplodeEvent) = onBlockEvent(event)

    @EventHandler(priority = EventPriority.MONITOR, ignoreCancelled = true)
    fun onBlock(event: BlockDestroyEvent) = onBlockEvent(event)

    @EventHandler(priority = EventPriority.MONITOR, ignoreCancelled = true)
    fun onBlock(event: BlockPistonExtendEvent) = onBlockEvent(event)

    private fun onBlockEvent(event: BlockEvent) {
        val block = event.block
        cache[block.world.uid]?.evict(block.x shr 4, block.z shr 4)
    }

    override suspend fun shutdown() {
        job?.cancel()
        job = null
        unregister()
    }
}

@Suppress("NOTHING_TO_INLINE")
inline fun chunkKey(x: Int, z: Int): Long {
    return x.toLong() and 4294967295L or ((z.toLong() and 4294967295L) shl 32)
}

val World.instanceSpace: PFInstanceSpace
    get() = KoinJavaComponent.get<InstanceSpaceCache>(InstanceSpaceCache::class.java).instanceSpace(this)

val com.typewritermc.core.utils.point.World.instanceSpace: PFInstanceSpace
    get() = KoinJavaComponent.get<InstanceSpaceCache>(InstanceSpaceCache::class.java).instanceSpace(this)