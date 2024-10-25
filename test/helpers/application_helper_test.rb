require 'test_helper'

class ApplicationHelperTest < ActionView::TestCase

#image_helper by_ratio, url
  test "image helper returns placeholder image url" do
    expected = "https://via.placeholder.com/480x320"
    assert_equal expected, image_helper()
  end

  test "image helper returns jpg image url" do
    expected = "https://test.com/image.jpg"
    assert_equal expected, image_helper("16by9", "https://test.com/image.jpg")
  end

  test "image helper parses image url containing params " do
    expected = "https://secure.ticketpro.ca/showPhoto.jpg?photoIndex=2&pageId=1333217816&version=4"
    assert_equal expected, image_helper("16by9", "https://secure.ticketpro.ca/showPhoto.jpg?photoIndex=2&pageId=1333217816&version=4")
  end

  test "image helper parses PNG " do
    expected = "https://test.com/photo.PNG"
    assert_equal expected, image_helper("16by9", "https://test.com/photo.PNG")
  end
  
  test "image helper parses jfif" do
    expected = "https://test.com/photo.jfif"
    assert_equal expected, image_helper("16by9", "https://test.com/photo.jfif")
  end

  test "image helper rejects invalid image extension" do
    expected = "https://via.placeholder.com/640x360"
    assert_equal expected, image_helper("16by9", "https://test.com/photo.BAD")
  end

  test "image helper ashx extension" do
    expected = "https://www.artsdrummondville.com/AttachmentImage.ashx?file=simon-gouache-nouveau-fiche.jpg&Size=63&UILanguageID=FR"
    assert_equal expected, image_helper("16by9", "https://www.artsdrummondville.com/AttachmentImage.ashx?file=simon-gouache-nouveau-fiche.jpg&Size=63&UILanguageID=FR")
  end

  test "image helper passes when no image extension" do
    expected = "https://calendar.sandersoncentre.ca/Default/Detail/2023-02-14-2000-An-Evening-with-Jann-Arden/64f10c40-7bcb-4fef-8d42-aea9012ea3c6"
    assert_equal expected, image_helper("16by9", "https://calendar.sandersoncentre.ca/Default/Detail/2023-02-14-2000-An-Evening-with-Jann-Arden/64f10c40-7bcb-4fef-8d42-aea9012ea3c6")
  end


  test "image helper not a URI" do
    expected = "https://via.placeholder.com/640x360"
    assert_equal expected, image_helper("16by9", "[]")
  end

  test "image helper with accent in url" do
    expected = "https://co-motion.ca/uploads/Spectacles/_1200x630_crop_center-center_82_none/François-Bellefeuille_2024.jpg"
    assert_equal expected, image_helper("16by9", "https://co-motion.ca/uploads/Spectacles/_1200x630_crop_center-center_82_none/François-Bellefeuille_2024.jpg")
  end
end
