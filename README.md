# Godot_Visual-PCG-PLugin


This is a plugin created for Godot 4.x and forwards, allowing users to create Procedural Environments and Assets(in the future) directly in the editor using a visual scripting system.

## Features
- Visual Scripting System: Create complex procedural generation logic using a node-based visual scripting interface.
- Real-time Preview: See the results of your procedural generation in real-time within the editor.
- Customizable Nodes: Create and customize your own nodes to suit your specific procedural generation needs.
- Asset Generation: Generate procedural assets such as terrain, buildings in simple 3D or hexagonal assets and more in the future.
- Integration with Godot's Scene System: Easily integrate your procedural generation logic into your scenes and game objects.
- Extensible Architecture: The plugin is designed to be extensible, allowing open source contributions and future PCG techniques to be added.

## How to use
1. Download the plugin from the GitHub repository and copy the `addons` folder into your
2. Godot project directory.
3. In the Godot editor, go to `Project > Project Settings > Plugins` and enable the `Visual PCG Plugin`.
4. You can now access the plugin's features through the `Visual PCG` tab in the editor. From there, you can create new procedural assets. Currently you can create maps with various 3D assets like `obj` files .
5. To start building hit the import tiles buttion import ur assets
6. Connect the various tiles through the socket system where you define the symmetry and the rules for how the tiles can connect to each other. You can also define the weights for each tile to control the probability of them being selected during the generation process.
7. Once you have set up your tiles and rules, you can generate your procedural environment by clicking the `Run WFC` button. The plugin will use the defined rules and weights to create a procedural environment based on the Wave Function Collapse algorithm.
8. The generated environment will be stored in the `res:/generated_levels` directory as 3d scenes you can easily add to your projects
9. You can adjust things such as grid type, grid size, and the number of iterations for the WFC algorithm to further customize your generated environment.



## Images




## TODO
- [ ] Make the normal 3D pipeline more intricate for collapsing with objects with different heights and more complex shapes
- [ ] Add more PCG tools just Perlin Noise as options 
- [ ] Runtime generation in games


## Note
This is currently a alpha build of the plugin developed initially as a indepdent study project and is not fully production ready. My intention was to create something that a basic godot user can use while a more advanced user can extend the plugin with me by working on adding additional features and improving the existing ones. I will be working on this plugin in my free time and will be adding more features and improving the existing ones as I go along. If you have any suggestions or want to contribute, feel free to reach out to me or submit a pull request on the GitHub repository.


## Special Thanks
- [Godot Engine](https://godotengine.org/) for providing an amazing game engine
- [Professor Urban](https://engineering.lehigh.edu/faculty/stephen-lee-urban) for his guidance and support throughout the development of this plugin
- []
