import 'package:flutter/material.dart';

/// One shared business taxonomy for the customer list, editor and detail.
/// Category ids are stored by the API; labels/colors/icons are presentation only.
class CustomerCategory {
  final String id, label;
  final IconData icon;
  final Color color;
  const CustomerCategory(this.id, this.label, this.icon, this.color);

  static const all = <CustomerCategory>[
    CustomerCategory('npp','Nhà phân phối',Icons.local_shipping_outlined,Color(0xFFE48223)),
    CustomerCategory('dai_ly','Đại lý',Icons.storefront_outlined,Color(0xFF6D249E)),
    CustomerCategory('nha_sach','Nhà sách',Icons.menu_book_outlined,Color(0xFF2675CE)),
    CustomerCategory('van_phong_pham','Văn phòng phẩm',Icons.edit_note_outlined,Color(0xFF25874E)),
    CustomerCategory('sieu_thi','Siêu thị',Icons.shopping_cart_outlined,Color(0xFFCC4B69)),
    CustomerCategory('tap_hoa','Tạp hóa',Icons.store_outlined,Color(0xFFA66B25)),
    CustomerCategory('cua_hang','Cửa hàng',Icons.shopping_bag_outlined,Color(0xFF148F9E)),
    CustomerCategory('truong_hoc','Trường học',Icons.school_outlined,Color(0xFF087F7B)),
    CustomerCategory('khach_le','Khách lẻ',Icons.person_outline,Color(0xFFC13C82)),
    CustomerCategory('khac','Khác',Icons.category_outlined,Color(0xFF758092)),
  ];

  static CustomerCategory fromId(String? id) {
    for (final option in all) {
      if (option.id == id) return option;
    }
    return all.last;
  }
}

class CustomerCategoryAvatar extends StatelessWidget {
  final String? category;
  const CustomerCategoryAvatar({super.key,required this.category});
  @override Widget build(BuildContext context) {
    final item=CustomerCategory.fromId(category);
    return Tooltip(message:item.label,child:CircleAvatar(
      backgroundColor:item.color.withValues(alpha:.20),
      child:Icon(item.icon,color:item.color),
    ));
  }
}

class CustomerCategoryLabel extends StatelessWidget {
  final String? category;
  const CustomerCategoryLabel({super.key,required this.category});
  @override Widget build(BuildContext context) {
    final item=CustomerCategory.fromId(category);
    return Row(mainAxisSize:MainAxisSize.min,children:[
      Icon(item.icon,color:item.color,size:18),
      const SizedBox(width:6),
      Flexible(child:Text(item.label,style:Theme.of(context).textTheme.bodyMedium)),
    ]);
  }
}

/// Business selling confirmation is independent of the customer's category
/// and active/inactive account status. Never recolor the type avatar itself.
class CustomerSellingDot extends StatelessWidget {
  final bool isSelling;
  final bool pending;
  const CustomerSellingDot({super.key,required this.isSelling,this.pending=false});
  static const sellingColor=Color(0xFF16A34A);
  static const unconfirmedColor=Color(0xFFEAB308);

  @override Widget build(BuildContext context) => Tooltip(
    message: isSelling
      ? (pending?'Đang bán · chờ đồng bộ':'Khách đang bán')
      : (pending?'Chưa bán · chờ đồng bộ':'Khách chưa bán'),
    child:Semantics(
      label:isSelling?'Trạng thái bán hàng: đang bán':'Trạng thái bán hàng: chưa bán',
      child:Container(
        key:const Key('customer-selling-dot'),
        width:10,height:10,
        decoration:BoxDecoration(
          shape:BoxShape.circle,
          color:isSelling?sellingColor:unconfirmedColor,
        ),
      ),
    ),
  );
}
