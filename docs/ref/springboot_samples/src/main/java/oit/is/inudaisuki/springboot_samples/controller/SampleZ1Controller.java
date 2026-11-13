package oit.is.inudaisuki.springboot_samples.controller;

import org.springframework.stereotype.Controller;
import org.springframework.ui.ModelMap;
import org.springframework.web.bind.annotation.GetMapping;

/**
 * SampleZ1Controller
 *
 * クラスの前に@Controllerをつけていると，HTTPリクエスト（GET/POSTなど）があったときに，このクラスが呼び出される
 */
@Controller
public class SampleZ1Controller {

  /**
   * @GetMapping アノテーションをつけると，HTTPリクエストのGETメソッドで/sampleZ1へのアクセスがあったときに，このメソッドが呼び出される
   * @param model
   * @return
   */
  @GetMapping("/sampleZ1")
  public String sampleZ1(ModelMap model) {
    int image = (int) (Math.random() * 3 + 1);// 1~3の乱数
    String imageUrl = image + "";// 乱数を文字列に変換
    String imageUrl2 = ".png";
    model.addAttribute("imageUrl", imageUrl);// テンプレート側でimageUrlという名前で参照できるようにする
    model.addAttribute("imageUrl2", imageUrl2);
    int image3 = (int) (Math.random() * 3 + 1);
    model.addAttribute("imageUrl3", image3 + ".png");

    return "sampleZ1.html";
  }

}
