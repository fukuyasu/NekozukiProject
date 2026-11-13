package oit.is.inudaisuki.springboot_samples.controller;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import oit.is.inudaisuki.springboot_samples.service.AsyncCount58;

/**
 * /sample58へのリクエストを扱うクラス
 * Controllerはhtmlを返すコントローラ
 * RestControllerはHTML画面名ではなく、HTTPレスポンス本体を直接返すコントローラ。
 * この例ではSseEmitterを返し、ブラウザへイベントを継続して送る。
 */
@RestController
@RequestMapping("/sample58")
public class Sample58Controller {
  // コンソールに出力したいログ情報を簡単に使えるようにするためのクラス
  // どこのクラスでもgetLogger内のクラス名を替えるだけで使える
  // 似たようなロガークラスが大量にあるので import org.slf4j.Logger; を間違えないようにすること
  private final Logger logger = LoggerFactory.getLogger(Sample58Controller.class);

  private final AsyncCount58 counter58;

  public Sample58Controller(AsyncCount58 counter58) {
    this.counter58 = counter58;
  }

  /**
   * @AuthenticationPrincipal ログインユーザの名前やロールを取得するためのアノテーション．Principalと違い，ロールも取得できる．
   * @param user
   * @return
   */
  @GetMapping("step1")
  public SseEmitter pushCount58(@AuthenticationPrincipal UserDetails user) {
    // infoレベルでログを出力する
    logger.info("pushCount");
    logger.info(user.getUsername());
    // SseEmitterの生成
    SseEmitter emitter = new SseEmitter(60000L); // タイムアウト時間を60秒に設定

    // "contains"による文字列検索ではなく、権限名そのものを比較する。
    String role = user.getAuthorities().stream()
        .map(authority -> authority.getAuthority())
        .filter(authority -> authority.equals("ROLE_CUSTOMER") || authority.equals("ROLE_SELLER"))
        .map(authority -> authority.substring("ROLE_".length()))
        .findFirst()
        // CUSTOMER、SELLER以外のログイン済みユーザにも、サンプルとして0を送る。
        .orElse("OTHER");

    this.counter58.startCount(emitter, role);
    return emitter;

  }
}
