package oit.is.inudaisuki.springboot_samples.controller;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import oit.is.inudaisuki.springboot_samples.service.AsyncCountFruit56;

/**
 * /sample56へのリクエストを扱うクラス
 */
@Controller
@RequestMapping("/sample56")
public class Sample56Controller {

  // コンソールに出力したいログ情報を簡単に使えるようにするためのクラス
  // どこのクラスでもgetLogger内のクラス名を替えるだけで使える
  // 似たようなロガークラスが大量にあるので import org.slf4j.Logger; を間違えないようにすること
  private final Logger logger = LoggerFactory.getLogger(Sample56Controller.class);

  private final AsyncCountFruit56 ac56;

  public Sample56Controller(AsyncCountFruit56 ac56) {
    this.ac56 = ac56;
  }

  /**
   * 数字をカウントアップしながらpushしつづけるメソッド
   *
   * @return
   */
  @GetMapping("step1")
  public SseEmitter pushCount() {
    // infoレベルでログを出力する
    logger.info("pushCount");

    // 60秒間通信がなければ一度接続を閉じる。EventSourceは自動的に再接続する。
    final SseEmitter emitter = new SseEmitter(60000L);
    this.ac56.startCount(emitter);
    return emitter;
  }

  @GetMapping("step2")
  public SseEmitter pushFruit() {
    // infoレベルでログを出力する
    logger.info("pushFruit");
    final SseEmitter sseEmitter = new SseEmitter(60000L);
    this.ac56.pushFruit(sseEmitter);
    return sseEmitter;

  }

}
