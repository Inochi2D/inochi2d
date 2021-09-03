# Inochi2D

Inochi2Dはリアルタイム2Dパペットアニメーションライブラリで、Inochi2DPuppetスタンダードのリファレンス実装です。

**現在、本ライブラリとスタンダードは試作段階です。実用は推奨しません。**
試用するには、本リポジトリを複製して、 `dub add-local (inochi2d folder) "1.0.0"` を実行し、手動でdub.sdl/json下に従属させてください。

https://user-images.githubusercontent.com/7032834/131196598-d8dee8a7-0c8c-455d-9cea-32183d459b44.mp4  
*初期試作動画*



# リギング

開発中の公式Inochi2Dリギングアプリ [Inochi Creator](https://github.com/Inochi2D/inochi-creator) を参照ください。
このリポジトリはスタンダード専用です。エンドユーザー向けのものではありません。



# サポート対象のプラットフォーム

リファレンスライブラリはOpenGL 4.2以降。パーツごとのシェーダーのSPIR-V ARB拡張機能のサポートが必要です。
*SPIR-Vが見つからない場合、カスタムシェーダーは無効になります。*

Inochi2Dは、他のグラフィックスAPIやアブストラクションを使用して自由に実装でき、ほとんどのグラフィックスAPI（OpenGL 2以降）で動作します。

バージョン1.0が完成した時点で、Unityへの実装が提供される予定です。



# Inochi2Dの仕組み

Inochi2Dでは、すべてのパーツ（テクスチャ）をノードオブジェクトのツリーに格納しています。
各ノードは個別の役割を持っています。

### パーツ

パーツには、モデルのテクスチャと頂点の情報が含まれています。
各パーツは、個別のテクスチャと頂点のセットです。

### パス変形 (PathDeforms)

パス変形は、ハンドルに基づいて子のドローアブルを変形させます。
同時に複数のドローアブルを変形させることができます。

### マスク

マスクは、シェイプを指定できるドローアブルです。
シェイプは、テクスチャ自体ではなく、パーツをマスクするのに使用されます。


*ノードの種類は今後も追加される予定です。*

### 注意点

*本仕様は現在製作中であり、変更される可能性があります。*
*詳細はスペックの1.0がリリースされた時点で公開となります。*



# Inochi2Dのブートストラップ

Inochi2Dのブートストラップは、お使いのバッキングウィンドウ管理ライブラリによって異なります。
Inochi2Dは、次のコードを用いてGLFW (bindbc)でブートストラップできます。

```// Loads GLFW
loadGLFW();
glfwInit();

// Create Window and initialize OpenGL 4.2 with compat profile
glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_COMPAT_PROFILE);
glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 2);
window = glfwCreateWindow(1024, 1024, "Inochi2D App".toStringz, null, null);

// Make OpenGL current and load its functions.
glfwMakeContextCurrent(window);
loadOpenGL();

// A timing function that returns the current applications runtime in seconds and milliseconds is needed
inInit(cast(double function())glfwGetTime);

// Get the viewport size, which is the size of the scene
int sceneWidth, sceneHeight;

// It is highly recommended to change the viewport with
// inSetViewport to match the viewport you want, otherwise it'll be 640x480
inSetViewport(1024, 1024);
inGetViewport(sceneWidth, sceneHeight);

// Also many vtuber textures are pretty big so let's zoom out a bit.
inGetCamera().scale = vec2(0.5);

// NOTE: If you want to implement camera switching (for eg camera presets) use
// inSetCamera

// NOTE: Loading API WIP, subject to change
Puppet myPuppet = inLoadPuppet("myPuppet.inp");

while(!glfwWindowShouldClose(window)) {
    // NOTE: Inochi2D does not itself clear the main framebuffer
    // you have to do that your self.
    glClear(GL_COLOR_BUFFER_BIT);

    // Run inUpdate first
    // This updates various submodules and time managment for animation
    inUpdate();

    // Imagine there's a lot of rendering code here
    // Maybe even some game logic or something

    // Begins drawing in to the Inochi2D scene
    // NOTE: You *need* to do this otherwise rendering may break
    inBeginScene();

        // Draw and update myPuppet.
        // Convention for using Inochi2D in D is to put everything
        // in a scene block one indent in.
        myPuppet.update();
        myPuppet.draw();

    // Ends drawing in to the Inochi2D scene.
    inEndScene();

    // Draw the scene, background is transparent
    inSceneDraw(vec4i(0, 0, sceneWidth, sceneHeight));

    // Do the buffer swapping and event polling last
    glfwSwapBuffers(window);
    glfwPollEvents();
}
```

### 注意
ダブ上のバーションは、最新の機能に従って常に更新されるわけではありません。以下のいずれかのリポジトリに関する操作を行ってください。

- inochi2Dを`dub.selections.json`ファイル下に従属させてから、お使いのバージョンに応じて`~master`を同ファイルに追加します。

- このレポジトリを複製して`dub add-local (inochi2d folder) "1.0.0"`を実行し、inochi2Dをローカルパッケージとして追加します。その後、`inochi2d`を従属として追加できます。



-------------------

Inochi2Dのロゴは[James Daniel](https://twitter.com/rakujira)氏によってデザインされました。

