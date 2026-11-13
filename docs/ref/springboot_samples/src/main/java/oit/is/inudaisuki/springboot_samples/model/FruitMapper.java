package oit.is.inudaisuki.springboot_samples.model;

import java.util.ArrayList;

import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

@Mapper
public interface FruitMapper {

  @Select("SELECT ID, NAME,PRICE FROM FRUIT")
  ArrayList<Fruit> selectAllFruit();

  @Select("select ID, NAME,PRICE from FRUIT WHERE ID = #{id}")
  Fruit selectById(int id);

  /**
   * update, insert, deleteでは抽象メソッドの返り値は (1)boolean:テーブルに1レコード以上何らかの変更が合ったかどうか
   * (2)void:返り値なし (3)int:テーブルに変更があったときの変更があったレコードの件数, のいずれかを設定できる
   *
   * @param id
   * @return
   */
  @Delete("DELETE FROM FRUIT WHERE ID =#{id}")
  boolean deleteById(int id);

  /**
   * 入力されたFruit Beanの値でDBを更新する {}内のフィールド名指定時には大文字小文字を間違えないようにすること （カラム名はOK）
   *
   * @param fruit
   */
  @Update("UPDATE FRUIT SET NAME=#{name}, PRICE=#{price} WHERE ID = #{id}")
  void updateById(Fruit fruit);

}
