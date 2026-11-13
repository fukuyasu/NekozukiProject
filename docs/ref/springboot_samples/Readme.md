# Springbootsamples
- Springbootを利用したWebアプリケーションの各種サンプル実装を行うサイト．
- 対象のSpringbootのver.はv2.5.4


## 環境構築
- 必要な開発環境は下記(private)を参照して構築すること
- https://github.com/igakilab/isdev/


## セットアップ（0からやる場合）
### Spring Initializrを利用したセットアップ
- 作成したいアプリの名前でフォルダを作成し，そのフォルダをvscodeで開く
- 表示->コマンドパレット，を選択し，Spring Initializr:Generate a Gradle Project を実行する
- Spring Initializr: Create a Gradle Project...
- Spring Boot version.
  - 2.5.4
  - ただし，この数値はすぐ変わるので，そのときそのときの最新の安定版(M3やSNAPSHOTと書いていないもの)を選択すること
- Specify project language: Java
- Input Group Id for your project: oit.is.inudaisuki
   - 例：jp.ac.hoge.is.inudaisuki
     - スペースや特殊文字を含めないこと．すべてアルファベット小文字．
     - 必ずしもjp.ac.hogeから始まらなくても良い
- Input Artifact Id for your project: springboot_samples
   - 例：dogland
   - スペースや特殊文字を含めないこと(_は入力できるが，不具合を誘発することがあるので使わないほうが良い)．すべてアルファベット小文字．また，セットアップ時に作成したフォルダ名と同じにしておくこと．
- packaging type
  - JAR
  Java version
  - 11
- dependencies
  - Spring Web, Thymeleaf, H2 Database, MyBatis Framework, Spring Securityの5つ
- [Generate into this folder]
  - springboot_samplesなどのフォルダがある場所と同じisdev21にjankenフォルダが作成されるようにすること
  - 作成後「Successfully generated. Location:..」と表示されるが，[Open][Add to Workspace]の **<span style="color:red">どちらも選択せずに×を選ぶこと</span>**
- .gitignore作成
- build.gradleを修正
  - tomcatでなくjettyを利用する設定を行う
     - `implementation 'org.springframework.boot:spring-boot-starter-jetty'`追加
     - 以下の`configurations`追加
```gradle
configurations {
  implementation.exclude group: 'org.springframework.boot', module: 'spring-boot-starter-tomcat'
}
```
  - security系のimplementation(3つ)をすべてコメントアウト（最初は認証系使わないので）


### application.properties
- `springboot_samples\src\main\resources\application.properties` に以下のような設定を追記
  - jetty周りの設定を追加しても良い
  - 参考 https://howtodoinjava.com/spring-boot2/logging/embedded-server-logging-config/
  - tomcatの場合はこちらを参考：https://www.baeldung.com/spring-boot-embedded-tomcat-logs

```java
server.port=8000
```

- ポート番号 `server.port=8000` を設定することで， http://localhost:8000/ でSpringBootアプリが動作するようになる

### index.htmlの配置
- `src/main/resource/static/index.html` を置く．index.htmlの中身はなんでもOK

### ~~SpringbootSamplesApplication.javaの修正~~
- 以下はbuild.gradleの修正ミスだったっぽい
- `@SpringBootApplication`を以下のように修正し，SecurityAutoConfigurationをimportする
  - Security機能を無効にする設定．build.gradleでsecurityをコメントアウトするとbootrun時にClassNotFoundと出てエラーになる

```java
import org.springframework.boot.autoconfigure.security.servlet.SecurityAutoConfiguration;

@SpringBootApplication(exclude = SecurityAutoConfiguration.class)
```

### SpringBootWebアプリの実行方法
- vscodeからターミナル->新しいターミナル，を選択し，bashのターミナルをエディタ下部に開く
- build.gradleファイルがあるのと同じディレクトリにいることを確認後，`gradle bootRun`を実行するとSpringBootアプリがビルドされ，組み込みjettyで起動する
  - `gradle build`を実行するとbuild/libs/ 以下に作成されるjarを対象に，java -jar ???.jar でもSpringBootWebアプリケーションを起動できる
- http://localhost:8000/ にアクセスしたときになにかWebページが表示されていればOK．
- 終了時は `gradle bootRun`を実行しているターミナルで，Ctr+Cを実行すれば良い
  - vscode内のターミナルではなく，別のターミナルで実行したときに，Ctr+Cが効かない場合がある．その場合は別のターミナルを開き，build.gradleがあるフォルダで`gradle --stop` と実行すると良い．