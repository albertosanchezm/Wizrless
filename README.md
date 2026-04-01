# Wizrless

Plataformas/acción 2D en Godot 4.6. El jugador controla a **Halbert**, un mago que se enfrenta a bosses usando hechizos.

---

## Stack técnico

- **Motor:** Godot 4.6, GDScript
- **IA:** LimboAI (LimboHSM) — máquinas de estado jerárquicas para player y bosses
- **Cámara:** PhantomCamera2D
- **Autoloads:** `GameManager`, `SceneManager`, `SaveManager`

---

## Capas de colisión

| Layer | Bit | Quién |
|-------|-----|-------|
| 1 | 1  | World (suelo, paredes estáticas) |
| 2 | 2  | Player body |
| 3 | 4  | Enemies body |
| 4 | 8  | Player hitbox (melee) |
| 5 | 16 | Proyectiles enemigos |
| 6 | 32 | Proyectiles del player |

---

## Estructura del proyecto

```
scenes/
  game.tscn
  player/player.tscn
  world/
    room_base.tscn
    rooms/room1.tscn          — sala inicial, punto de respawn
    rooms/room2.tscn          — sala del boss Devium, barrera de combate
  enemies/devium.tscn
  projectiles/
    fireball.tscn
    ice_ball.tscn
    ice_ball_fragment.tscn
    ice_rock.tscn
    parabolic_ball.tscn
  hazards/ground_spike.tscn
  effects/
    damage_number.tscn
    burn_indicator.tscn
  ui/hud.tscn

scripts/
  systems/
    game_manager.gd           — estado global, señales, vida, respawn
    scene_manager.gd          — cambio de sala
    save_manager.gd
  player/
    player.gd
    states/                   — idle, run, jump, fall, dash, attack, death
  enemies/devium/
    devium.gd
    states/                   — idle, levitate, ice_ball, ice_rocks, ground_spikes, parabolic, death
  projectiles/                — fireball, ice_ball, ice_ball_fragment, ice_rock, parabolic_ball
  hazards/ground_spike.gd
  effects/
    damage_number.gd
    burn_indicator.gd
  world/
    room.gd
    room_exit.gd
    combat_barrier.gd
  ui/hud.gd
```

---

## Player — Halbert

### Stats
| Parámetro | Valor |
|-----------|-------|
| Velocidad | 90 px/s |
| Salto | -260 px/s |
| Gravedad / Caída | 900 / 1400 |
| Vel. máx. caída | 500 px/s |
| Coyote time | 0.12s |
| Jump buffer | 0.10s |
| Dash velocidad | 220 px/s durante 0.18s (CD 0.6s) |
| Cooldown ataque | 1.5s |
| Maná máx. | 100 |
| Coste por disparo | 25 (máx 4 seguidos) |
| Regen maná | 10/s tras 1.5s sin disparar |
| Vida | 100 HP |

### Habilidades desbloqueables
`double_jump` · `dash` · `wall_jump` · `wall_slide`

### Ataque — Fireball
- Disparo horizontal; diagonal 45° si se mantiene `move_up`
- Destrucción mutua con `ice_ball` al colisionar
- Layer 32, mask 17 (world + enemy projectiles)

### Muerte y respawn
- `death_state.gd` awaita `SceneManager.change_room(respawn_scene)` → restaura vida → dispatch "land"
- `room.gd` registra el punto de spawn con `GameManager.set_respawn(pos, room_id, scene_path)`

---

## Boss — Devium

### Stats
| Parámetro | Valor |
|-----------|-------|
| Vida | 100 HP |
| Fase 2 | ≤ 60 HP (60%) |

### Activación
Entra en combate cuando Halbert se acerca a 200 px. Al activarse emite `GameManager.boss_appeared` → aparece la barra de boss en el HUD.

### Movimiento — Lissajous dual
Dos osciladores independientes (X: 1.1 rad/s, Y: 1.7 rad/s) crean un path de Lissajous no periódico:

```
rx = (BASE_RX + VAR_R·sin(t·BREATH_FREQ)) · radius_factor
ry = rx · ELLIPSE_Y

anchor = orbit_center + Vector2(cos(t·1.1)·rx, sin(t·1.7)·ry + Y_OFFSET)
```

- `BASE_RX=110`, `VAR_R=60`, `ELLIPSE_Y=0.85` (recorrido vertical amplio)
- Si el player está quieto > 2s, `radius_factor` baja hasta 0.45 (Devium se acerca)
- Devium se mueve hacia el ancla a 95 px/s

### Ataques

#### Fase 1
| Ataque | Descripción | Daño |
|--------|-------------|------|
| Ice Ball | Proyectil recto que fragmenta al impactar en 3 esquirlas | 15 + 5×3 fragmentos |
| Ice Rocks | Rocas que caen con gravedad desde arriba (sombra en suelo) | 12 |

#### Fase 2 (adicionales)
| Ataque | Descripción | Daño |
|--------|-------------|------|
| Ground Spikes | Pinchos que emergen del suelo bajo el player; 2ª oleada desplazada | 20 |
| Parabolic | Abanico de bolas con gravedad | 10 × N |

**Selección de ataque:** anti-repeat + contexto de distancia (lejos → ice_ball, cerca → ice_rocks).  
**Timing:** fase 1 cada 1.5s, fase 2 cada 1.0s.

#### Ice Ball — fragmentos por impacto
Calcula la normal de la superficie impactada a partir de la dirección de viaje:
- `|dir.y| ≥ |dir.x|` → normal = UP (suelo) o DOWN (techo)
- en caso contrario → normal = LEFT/RIGHT (pared)

3 fragmentos en arco de 90° centrado en la normal, bases -45°/0°/+45° con ±15° de jitter aleatorio.

### Sistema de quemadura
Dos impactos de fireball dentro de una ventana de **2.5s** activan la quemadura:
- **Duración:** 4s
- **Tick:** cada 0.8s → 5 HP de daño (total: 25 HP en 5 ticks)
- Mientras está activa, aparece un indicador de llama sobre Devium

### Muerte
- `die()` emite `died` + `GameManager.boss_defeated` → oculta barra de boss, desaparece barrera

---

## HUD

| Zona | Contenido |
|------|-----------|
| Top-left | Barra de vida (rojo) + Barra de maná (azul) |
| Top-right | Barra de cooldown de fireball + etiqueta "LISTA" / "X.Xs" |
| Bottom-left | Iconos de habilidades (opaco al desbloquear) |
| Bottom-center | **Barra de boss** (morado, oculta por defecto) — aparece al salir del idle |

### Números de daño flotantes (`DamageNumber`)
- `class_name DamageNumber`, spawn estático global
- Color blanco = daño normal · rojo = daño al player · naranja = quemadura
- Texto en world-space con `draw_string()`, desvanece y sube durante ~0.8s

---

## Señales de GameManager

| Señal | Emisor | Receptor |
|-------|--------|----------|
| `health_changed(cur, max)` | GameManager.take_damage / heal | HUD HealthBar |
| `mana_changed(cur, max)` | player.use_mana / regen | HUD ManaBar |
| `ability_unlocked(name)` | GameManager.unlock_ability | HUD Abilities |
| `attack_cooldown_changed(rem, total)` | player._tick_timers | HUD CooldownBar |
| `player_died` | GameManager.take_damage | death_state, HUD boss bar |
| `boss_appeared(name, max_hp)` | devium idle_state | HUD BossContainer |
| `boss_health_changed(cur, max)` | devium.take_damage | HUD BossBar |
| `boss_defeated()` | devium.die | HUD BossContainer |

---

## Notas de debug activas

- **Player inmortal:** `GameManager.take_damage` clampea a mínimo 1 HP (no emite `player_died`). Revertir para build final.
