use bevy::{
    input::mouse::{MouseMotion, MouseWheel},
    pbr::wireframe::{WireframeConfig, WireframePlugin},
    prelude::*,
    reflect::TypePath,
    render::render_resource::{AsBindGroup, ShaderRef},
    window::PrimaryWindow,
};

/*
+Зробити рухабельну камеру
+Спробувати передавати через матеріал параметр з режимом формування поверхні
+Перевірити як працює формування різних режимів формування поверхні (можна на 0 посадити рівну поверхню)
Вписати сюди різні види шумів

*/

#[derive(Component)]
struct PanOrbitCamera {
    /// The "focus point" to orbit around. It is automatically updated when panning the camera
    pub focus: Vec3,
    pub radius: f32,
    pub upside_down: bool,
}

impl Default for PanOrbitCamera {
    fn default() -> Self {
        PanOrbitCamera {
            focus: Vec3::ZERO,
            radius: 5.0,
            upside_down: false,
        }
    }
}

fn main() {
    App::new()
        .add_plugins((
            DefaultPlugins
                .set(AssetPlugin {
                    watch_for_changes_override: Some(true),
                    ..Default::default()
                })
                .set(WindowPlugin {
                    primary_window: Some(Window {
                        title: MODES[0].2.to_string(),
                        ..Default::default()
                    }),
                    ..Default::default()
                }),
            MaterialPlugin::<CustomMaterial>::default(),
            WireframePlugin,
        ))
        // .insert_resource(WireframeConfig {
        //     // The global wireframe config enables drawing of wireframes on every mesh,
        //     // except those with `NoWireframe`. Meshes with `Wireframe` will always have a wireframe,
        //     // regardless of the global configuration.
        //     global: true,
        //     // Controls the default color of all wireframes. Used as the default color for global wireframes.
        //     // Can be changed per mesh using the `WireframeColor` component.
        //     default_color: Color::WHITE,
        // })
        .add_systems(Startup, setup)
        .add_systems(Update, (pan_orbit_camera, change_material_properties))
        .run();
}

fn setup(
    mut commands: Commands,
    mut meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<CustomMaterial>>,
    // mut materials: ResMut<Assets<StandardMaterial>>,
) {
    let mut plane = Mesh::from(shape::Plane {
        size: 50.0,
        subdivisions: 512,
    });
    let point_count = plane.count_vertices();
    plane.insert_attribute(
        Mesh::ATTRIBUTE_COLOR,
        vec![[0.0, 1.0, 0.0, 1.0]; point_count],
    );

    commands.spawn(MaterialMeshBundle {
        mesh: meshes.add(plane),
        // transform: Transform::from_xyz(0.0, 0.0, 0.0),
        // material: materials.add(Color::GREEN.into()),
        material: materials.add(CustomMaterial { mode: 0 }),
        ..default()
    });

    // light
    commands.spawn(PointLightBundle {
        point_light: PointLight {
            intensity: 1500.0,
            shadows_enabled: true,
            ..default()
        },
        transform: Transform::from_xyz(4.0, 8.0, 4.0),
        ..default()
    });

    spawn_camera(commands, Vec3::new(0.0, 6., 12.0));
}

fn spawn_camera(mut commands: Commands, translation: Vec3) {
    let radius = translation.length();

    commands.spawn((
        Camera3dBundle {
            transform: Transform::from_translation(translation).looking_at(Vec3::ZERO, Vec3::Y),
            ..Default::default()
        },
        PanOrbitCamera {
            radius,
            ..Default::default()
        },
    ));
}

/// Inspired by bevy cheatbook example <https://bevy-cheatbook.github.io/cookbook/pan-orbit-camera.html>
/// Pan the camera with middle mouse click, zoom with scroll wheel, orbit with right mouse click.
fn pan_orbit_camera(
    windows: Query<&Window, With<PrimaryWindow>>,
    mut ev_motion: EventReader<MouseMotion>,
    mut ev_scroll: EventReader<MouseWheel>,
    input_mouse: Res<Input<MouseButton>>,
    mut query: Query<(&mut PanOrbitCamera, &mut Transform, &Projection)>,
) {
    // change input mapping for orbit and panning here
    let orbit_button = MouseButton::Right;
    let pan_button = MouseButton::Middle;

    let mut pan = Vec2::ZERO;
    let mut rotation_move = Vec2::ZERO;
    let mut scroll: f32 = 0.0;
    let mut orbit_button_changed = false;

    if input_mouse.pressed(orbit_button) {
        for ev in ev_motion.read() {
            rotation_move += ev.delta;
        }
    } else if input_mouse.pressed(pan_button) {
        // Pan only if we're not rotating at the moment
        for ev in ev_motion.read() {
            pan += ev.delta;
        }
    }
    for ev in ev_scroll.read() {
        scroll += ev.y;
    }
    if input_mouse.just_released(orbit_button) || input_mouse.just_pressed(orbit_button) {
        orbit_button_changed = true;
    }

    for (mut pan_orbit, mut transform, projection) in &mut query {
        if orbit_button_changed {
            // only check for upside down when orbiting started or ended this frame
            // if the camera is "upside" down, panning horizontally would be inverted, so invert the input to make it correct
            let up = transform.rotation * Vec3::Y;
            pan_orbit.upside_down = up.y <= 0.0;
        }

        let mut any = false;
        if rotation_move.length_squared() > 0.0 {
            any = true;
            let window = get_primary_window_size(&windows);
            let delta_x = {
                let delta = rotation_move.x / window.x * std::f32::consts::PI * 2.0;
                if pan_orbit.upside_down {
                    -delta
                } else {
                    delta
                }
            };
            let delta_y = rotation_move.y / window.y * std::f32::consts::PI;
            let yaw = Quat::from_rotation_y(-delta_x);
            let pitch = Quat::from_rotation_x(-delta_y);
            transform.rotation = yaw * transform.rotation; // rotate around global y axis
            transform.rotation *= pitch; // rotate around local x axis
        } else if pan.length_squared() > 0.0 {
            any = true;
            // make panning distance independent of resolution and FOV,
            let window = get_primary_window_size(&windows);
            if let Projection::Perspective(projection) = projection {
                pan *= Vec2::new(projection.fov * projection.aspect_ratio, projection.fov) / window;
            }
            // translate by local axes
            let right = transform.rotation * Vec3::X * -pan.x;
            let up = transform.rotation * Vec3::Y * pan.y;
            // make panning proportional to distance away from focus point
            let translation = (right + up) * pan_orbit.radius;
            pan_orbit.focus += translation;
        } else if scroll.abs() > 0.0 {
            any = true;
            pan_orbit.radius -= scroll * pan_orbit.radius * 0.2;
            // dont allow zoom to reach zero or you get stuck
            pan_orbit.radius = f32::max(pan_orbit.radius, 0.05);
        }

        if any {
            // emulating parent/child to make the yaw/y-axis rotation behave like a turntable
            // parent = x and y rotation
            // child = z-offset
            let rot_matrix = Mat3::from_quat(transform.rotation);
            transform.translation =
                pan_orbit.focus + rot_matrix.mul_vec3(Vec3::new(0.0, 0.0, pan_orbit.radius));
        }
    }

    // consume any remaining events, so they don't pile up if we don't need them
    // (and also to avoid Bevy warning us about not checking events every frame update)
    ev_motion.clear();
}

const MODES: [(KeyCode, u32, &'static str); 6] = [
    (KeyCode::Key0, 0, "No noise, just flat surface"),
    (KeyCode::Key1, 1, "Just random values"),
    (KeyCode::Key2, 2, "Gradient noise"),
    (KeyCode::Key3, 3, "Gradient noise with smoothness"),
    (KeyCode::Key4, 4, "Perlin noise"),
    (KeyCode::Key5, 5, "Simplex noise"),
];

fn change_material_properties(
    input_key: Res<Input<KeyCode>>,
    handles: Query<&Handle<CustomMaterial>>,
    mut custom_materials: ResMut<Assets<CustomMaterial>>,
    mut window_query: Query<&mut Window, With<PrimaryWindow>>,
) {
    for mode in MODES {
        if input_key.just_pressed(mode.0) {
            if let Some(material) = custom_materials.get_mut(handles.single()) {
                material.mode = mode.1;
                if let Ok(mut window) = window_query.get_single_mut() {
                    window.title = mode.2.to_string();
                }
                break;
            }
        }
    }
}

fn get_primary_window_size(windows: &Query<&Window, With<PrimaryWindow>>) -> Vec2 {
    let window = windows.get_single().unwrap();
    Vec2::new(window.width(), window.height())
}

#[derive(Asset, TypePath, AsBindGroup, Debug, Clone)]
struct CustomMaterial {
    #[uniform(0)]
    mode: u32,
}

impl Material for CustomMaterial {
    fn vertex_shader() -> ShaderRef {
        "shaders/noise.wgsl".into()
    }
}
