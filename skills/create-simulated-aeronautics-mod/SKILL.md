---
name: create-simulated-aeronautics-mod
description: Expert skill for building and developing the Create Simulated Project — a NeoForge Minecraft mod suite adding physics-based contraptions, airships, planes, cars, and more to Create mod.
triggers:
  - "help me with create aeronautics mod"
  - "how do I add a physics contraption to minecraft"
  - "create simulated project setup"
  - "neoforge minecraft mod with create"
  - "build airship plane car minecraft mod"
  - "create mod physics extension"
  - "simulated contraption assembly code"
  - "aeronautics offroad mod development"
---

# Create Simulated Project (Aeronautics) Development Skill

> Skill by [ara.so](https://ara.so) — Daily 2026 Skills collection.

## What This Project Is

The **Create Simulated Project** is a suite of NeoForge Minecraft mods that extend the [Create](https://github.com/Creators-of-Create/Create) mod with real physics-based contraptions. It is composed of three main submodules:

| Module | Purpose |
|---|---|
| **Simulated** | Core: assembly, redstone components, physics API |
| **Aeronautics** | Flying contraptions: propellers, hot air, floating rocks |
| **Offroad** | Land vehicles: wheels, ground physics |

Physics is powered by [Sable](https://github.com/ryanhcode/sable), a custom physics engine integrated with Minecraft's world.

---

## Repository Structure

```
Simulated-Project/
├── simulated/          # Core mod (assembly, physics base)
│   └── src/main/java/com/simulated/
├── aeronautics/        # Flying mod
│   └── src/main/java/com/aeronautics/
├── offroad/            # Land vehicle mod
│   └── src/main/java/com/offroad/
├── gradle/
├── build.gradle
├── settings.gradle
└── gradle.properties
```

---

## Prerequisites

- **Java 21** (NeoForge 1.21+ requires Java 21)
- **Gradle 8+** (wrapper included)
- **NeoForge MDK** familiarity
- **Create mod** as a dependency (declared in `build.gradle`)

---

## Setup & Installation (Development)

### 1. Clone the Repository

```bash
git clone https://github.com/Creators-of-Aeronautics/Simulated-Project.git
cd Simulated-Project
```

### 2. Generate IDE Run Configurations

```bash
# IntelliJ IDEA
./gradlew genIntellijRuns

# Eclipse
./gradlew genEclipseRuns

# VS Code
./gradlew genVSCodeRuns
```

### 3. Build the Mod JARs

```bash
./gradlew build
# Output JARs in: simulated/build/libs/, aeronautics/build/libs/, offroad/build/libs/
```

### 4. Run the Development Client

```bash
./gradlew runClient
```

### 5. Run a Development Server

```bash
./gradlew runServer
```

---

## Key Gradle Commands

```bash
./gradlew build              # Build all subprojects
./gradlew runClient          # Launch Minecraft client with mods loaded
./gradlew runServer          # Launch dedicated server
./gradlew genIntellijRuns    # Generate IntelliJ run configs
./gradlew clean              # Clean build artifacts
./gradlew :simulated:build   # Build only the simulated subproject
./gradlew :aeronautics:build # Build only aeronautics
./gradlew :offroad:build     # Build only offroad
```

---

## Mod Installation (End User)

1. Install [NeoForge](https://neoforged.net/) for your Minecraft version.
2. Install [Create mod](https://modrinth.com/mod/create) for NeoForge.
3. Download the mod JARs from [Modrinth](https://modrinth.com/project/create-aeronautics).
4. Place all JARs into your `.minecraft/mods/` folder.
5. Launch the game.

---

## Core Concepts & Architecture

### Physics Contraptions

Simulated extends Create's `Contraption` system by wrapping contraption assemblies in a **Sable physics body**. When a player assembles a contraption using a special block, the contraption is handed off to the physics simulation.

### Assembly Flow

```
Player uses Assembly Block
        ↓
ContraptionAssembler.assemble()
        ↓
PhysicsContraption created
        ↓
Sable RigidBody spawned in physics world
        ↓
Forces applied each tick (thrust, lift, gravity, drag)
        ↓
Contraption position synced to clients
```

---

## Key Code Patterns

### Registering a New Block (NeoForge DeferredRegister)

```java
import net.neoforged.neoforge.registries.DeferredRegister;
import net.neoforged.neoforge.registries.DeferredBlock;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.state.BlockBehaviour;
import net.minecraft.core.registries.Registries;

public class SimulatedBlocks {

    public static final DeferredRegister.Blocks BLOCKS =
        DeferredRegister.createBlocks("simulated");

    public static final DeferredBlock<Block> MY_PHYSICS_BLOCK =
        BLOCKS.registerSimpleBlock(
            "my_physics_block",
            BlockBehaviour.Properties.of()
                .strength(2.0f, 6.0f)
                .requiresCorrectToolForDrops()
        );
}
```

### Registering Block Items

```java
public class SimulatedItems {
    public static final DeferredRegister.Items ITEMS =
        DeferredRegister.createItems("simulated");

    public static final DeferredItem<BlockItem> MY_PHYSICS_BLOCK_ITEM =
        ITEMS.registerSimpleBlockItem(SimulatedBlocks.MY_PHYSICS_BLOCK);
}
```

### Attaching Registries in the Main Mod Class

```java
@Mod("simulated")
public class SimulatedMod {

    public SimulatedMod(IEventBus modEventBus) {
        SimulatedBlocks.BLOCKS.register(modEventBus);
        SimulatedItems.ITEMS.register(modEventBus);
        // Register other deferred registers here
    }
}
```

---

### Creating a Custom Force Provider (Lift, Thrust, etc.)

Force providers apply physics forces to a simulated contraption each tick. This is the core extension point for Aeronautics-style effects.

```java
import com.simulated.physics.ForceProvider;
import com.simulated.physics.PhysicsContraption;
import org.joml.Vector3d;

/**
 * Example: A simple upward lift force provider (like a balloon).
 */
public class BalloonLiftForce implements ForceProvider {

    private final double liftStrength;

    public BalloonLiftForce(double liftStrength) {
        this.liftStrength = liftStrength;
    }

    @Override
    public void applyForces(PhysicsContraption contraption, double deltaTime) {
        // Get the current rigid body from Sable
        var body = contraption.getRigidBody();

        // Apply upward force scaled by lift strength and delta time
        Vector3d liftForce = new Vector3d(0, liftStrength * deltaTime, 0);
        body.applyForce(liftForce, body.getCenterOfMass());
    }
}
```

---

### Registering a Force Provider

```java
// During contraption assembly or via a special block's behavior:
PhysicsContraption contraption = ...; // obtained from assembly context
contraption.addForceProvider(new BalloonLiftForce(500.0));
```

---

### Custom Block Entity with Physics Interaction

```java
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.entity.BlockEntityType;
import net.minecraft.core.BlockPos;
import net.minecraft.world.level.block.state.BlockState;
import com.simulated.physics.PhysicsContraption;

public class PropellerBlockEntity extends BlockEntity {

    private double thrustOutput = 0.0;

    public PropellerBlockEntity(BlockEntityType<?> type, BlockPos pos, BlockState state) {
        super(type, pos, state);
    }

    /**
     * Called each physics tick when this block is part of an assembled contraption.
     */
    public void onPhysicsTick(PhysicsContraption contraption, double deltaTime) {
        if (thrustOutput <= 0) return;

        // Determine thrust direction from block facing
        var facing = getBlockState().getValue(net.minecraft.world.level.block.DirectionalBlock.FACING);
        var direction = new org.joml.Vector3d(
            facing.getStepX() * thrustOutput * deltaTime,
            facing.getStepY() * thrustOutput * deltaTime,
            facing.getStepZ() * thrustOutput * deltaTime
        );

        contraption.getRigidBody().applyForce(direction,
            contraption.getRigidBody().getCenterOfMass());
    }

    public void setThrustOutput(double thrust) {
        this.thrustOutput = thrust;
        setChanged();
    }
}
```

---

### Handling Contraption Assembly Events

```java
import net.neoforged.bus.api.SubscribeEvent;
import net.neoforged.fml.common.EventBusSubscriber;
import com.simulated.event.ContraptionAssembleEvent;

@EventBusSubscriber(modid = "mymod")
public class ContraptionEventHandler {

    @SubscribeEvent
    public static void onContraptionAssemble(ContraptionAssembleEvent event) {
        PhysicsContraption contraption = event.getContraption();

        // Example: scan for balloon blocks and add lift accordingly
        int balloonCount = contraption.countBlocksOfType(MyBlocks.BALLOON.get());
        if (balloonCount > 0) {
            contraption.addForceProvider(new BalloonLiftForce(balloonCount * 200.0));
        }
    }
}
```

---

### Client-Side Rendering a Physics Contraption

```java
import com.mojang.blaze3d.vertex.PoseStack;
import net.minecraft.client.renderer.MultiBufferSource;
import net.neoforged.api.distmarker.Dist;
import net.neoforged.api.distmarker.OnlyIn;
import com.simulated.client.render.PhysicsContraptionRenderer;

@OnlyIn(Dist.CLIENT)
public class MyContraptionRenderer extends PhysicsContraptionRenderer {

    @Override
    public void renderContraption(
        PhysicsContraption contraption,
        PoseStack poseStack,
        MultiBufferSource bufferSource,
        float partialTick
    ) {
        poseStack.pushPose();

        // Apply interpolated physics transform for smooth rendering
        applyPhysicsTransform(contraption, poseStack, partialTick);

        // Delegate block rendering to super
        super.renderContraption(contraption, poseStack, bufferSource, partialTick);

        poseStack.popPose();
    }
}
```

---

### Networking: Syncing Contraption State to Client

```java
import net.neoforged.neoforge.network.handling.IPayloadContext;
import net.minecraft.network.protocol.common.custom.CustomPacketPayload;
import net.minecraft.network.codec.StreamCodec;
import net.minecraft.network.FriendlyByteBuf;

public record ContraptionSyncPayload(
    int contraptionId,
    double posX, double posY, double posZ,
    double quatX, double quatY, double quatZ, double quatW
) implements CustomPacketPayload {

    public static final CustomPacketPayload.Type<ContraptionSyncPayload> TYPE =
        new CustomPacketPayload.Type<>(
            net.minecraft.resources.ResourceLocation.fromNamespaceAndPath("simulated", "contraption_sync")
        );

    public static final StreamCodec<FriendlyByteBuf, ContraptionSyncPayload> CODEC =
        StreamCodec.ofMember(
            (payload, buf) -> {
                buf.writeInt(payload.contraptionId());
                buf.writeDouble(payload.posX());
                buf.writeDouble(payload.posY());
                buf.writeDouble(payload.posZ());
                buf.writeDouble(payload.quatX());
                buf.writeDouble(payload.quatY());
                buf.writeDouble(payload.quatZ());
                buf.writeDouble(payload.quatW());
            },
            buf -> new ContraptionSyncPayload(
                buf.readInt(),
                buf.readDouble(), buf.readDouble(), buf.readDouble(),
                buf.readDouble(), buf.readDouble(), buf.readDouble(), buf.readDouble()
            )
        );

    @Override
    public Type<? extends CustomPacketPayload> type() {
        return TYPE;
    }
}
```

---

## Configuration

Simulated Project uses NeoForge's config system. Config files appear in `.minecraft/config/` after first launch.

```java
import net.neoforged.neoforge.common.ModConfigSpec;

public class SimulatedConfig {

    public static final ModConfigSpec.Builder BUILDER = new ModConfigSpec.Builder();
    public static final ModConfigSpec SPEC;

    public static final ModConfigSpec.DoubleValue GLOBAL_LIFT_MULTIPLIER;
    public static final ModConfigSpec.BooleanValue ENABLE_DRAG;
    public static final ModConfigSpec.IntValue MAX_CONTRAPTION_BLOCKS;

    static {
        BUILDER.push("physics");

        GLOBAL_LIFT_MULTIPLIER = BUILDER
            .comment("Multiplier applied to all lift forces. Default: 1.0")
            .defineInRange("globalLiftMultiplier", 1.0, 0.1, 10.0);

        ENABLE_DRAG = BUILDER
            .comment("Whether aerodynamic drag is simulated.")
            .define("enableDrag", true);

        MAX_CONTRAPTION_BLOCKS = BUILDER
            .comment("Maximum blocks allowed in a physics contraption.")
            .defineInRange("maxContraptionBlocks", 2048, 1, 10000);

        BUILDER.pop();
        SPEC = BUILDER.build();
    }
}
```

Register the config in your mod constructor:

```java
ModLoadingContext.get().registerConfig(ModConfig.Type.COMMON, SimulatedConfig.SPEC);
```

---

## Localization (Crowdin / en_us.json)

Translations are managed via [Crowdin](https://crowdin.com/project/create-aeronautics). To add new translatable strings:

```json
// src/main/resources/assets/simulated/lang/en_us.json
{
  "block.simulated.my_physics_block": "My Physics Block",
  "tooltip.simulated.my_physics_block": "A block that interacts with physics contraptions.",
  "item.simulated.my_item": "My Physics Item"
}
```

---

## Common Patterns & Gotchas

### Physics runs on the Server Thread
Never access Sable physics bodies from the client render thread directly. Use packets to sync state.

### Contraption Block Scanning
Use `contraption.getBlocks()` or `contraption.countBlocksOfType()` after assembly — not during world ticks on un-assembled contraptions.

### Partial Tick Interpolation
For smooth rendering, always interpolate between the previous and current physics transform using `partialTick`:

```java
// Inside a renderer:
Vector3d renderPos = prevPos.lerp(currentPos, partialTick);
Quaterniond renderRot = prevRot.slerp(currentRot, partialTick);
```

### Sable Rigid Body Units
Sable uses **SI units internally** (meters, kilograms, seconds). One Minecraft block = 1 meter. Mass should be set in kilograms; typical contraption mass: 500–50,000 kg depending on block count.

---

## Troubleshooting

| Problem | Solution |
|---|---|
| Contraption falls through the world | Check that collision shapes are registered for all blocks via `Block.getShape()` |
| Physics stutters / rubber-bands | Ensure server tick rate is stable; check `maxContraptionBlocks` config |
| Client contraption desyncs | Verify sync packets are being sent each tick with correct contraption ID |
| Mod fails to load | Confirm Create mod version matches the version specified in `gradle.properties` |
| `ClassNotFoundException` for Sable classes | Ensure Sable is included in `dependencies {}` and shadowed or provided correctly |
| Gradle build fails | Run `./gradlew --refresh-dependencies` and confirm Java 21 is active (`java -version`) |

---

## Contributing

1. Fork the repository.
2. Create a branch: `git checkout -b feature/my-feature`
3. Follow existing code style (Google Java Format, 4-space indent).
4. Submit a PR against `main`.
5. Join [Discord](https://discord.gg/createaeronautics) for design discussions.

Translation contributions go through [Crowdin](https://crowdin.com/project/create-aeronautics) — do not open PRs for lang files.
