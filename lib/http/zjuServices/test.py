import requests

s = requests.Session()
# 先把浏览器里已有的 cookie 填上，或通过登录拿到
s.cookies.update({
    'SESSION': 'ZGQzMmEwOTktZTI1My00MDBiLTkxMDAtOTU0YjEyMWY4NzM3',
    '_csrf': 'S8mwplVi9KWoF2WQ0TlCeJmGdJulhcmfvidTHJEsjG4%3D',
    '__root_domain_v': '.zju.edu.cn',
    '_clck': 'm3p4j5%5E2%5Eg0o%5E0%5E2014',
    # 重复或混乱项删除，整理规范命名，保持格式正确
    '_ga': 'GA1.1.2126540813.1751900195',
    '_ga_H5QC8W782Q': 'GS2.1.s1762149234$o2$g0$t1762149351$j60$l0$h0',
    '_ga_MWF1PQPJ1G': 'GS2.1.s1762093994$o7$g1$t1762096535$j27$l0$h0',
    '_ga_RHW3V3MQEE': 'GS2.1.s1761271537$o2$g1$t1761271559$j38$l0$h0',
    '_pc': '05TUWPvojzR9e7gCnRUWL4xyS8u5pml5ZhYnGwP8uyt1BgjV2VzJOrCST0Xami6il',
    '_pf': '0O5iwrVgqbYg8VXzpIz5nv3egKu2zoStVxW2DhiPwlDM%3D',
    '_pv': '06GL%2B0S%2Foum%2BYy4lrK3KnjJ4PFfYIXwtm71oPQy7CQzSaMjOfNQcRYEFc9rM0F%2B9LUefKSZopWm7I%2Bffxn07kNb6rcqHsunsWbzyQ9m%2FAG2W4a0J5CfTFg51SwXXDkYtvxDtMUBKozLH8UlBKOT487MjQDRej36eFjzrDoQVGjR%2FY%2F8EzbohTzwJuI2h048e0Alm6BPSPbjmjvVWxxBpVZ7gx378gmfpA0fm5GCEUcuYptThnSE2S1ih%2FavogYaBoqOEm1%2Fa32WA3xnHrfczK5mS2nSErQ6q3Dz1ltCgpk%2Fl%2FBmR4M7HphUg9MYwYbNbhLjCO3CBE%2Bpb398bofoMNzbJ%2BO%2BI0o1V0mJLGVHZDdVrRdZGYFzGUUhgM6qCHPj%2FwDiaWk6R6f3uwgEys4i0HvyVlopZ%2B4EzS1%2Fh4b83hhG4%3D',
    '_qddaz': 'QD.852262169074724',
    'device_token': '6aa8e19e7173246c44b535414d84463f',
    'Hm_lpvt_35da6f287722b1ee93d185de460f8ba2': '1762101990',
    'Hm_lvt_35da6f287722b1ee93d185de460f8ba2': '1762101980',
    'HMACCOUNT': '97C0C0498218A583',
    'iPlanetDirectoryPro': 'Dq%2BrNwamgqrKIYPpV7hSXY2cKyHjWKREwP1KrA5v9krmdyC8AMhm3M3XbcdXUQOTAvSaTB0lbC%2BE6yQDndBhYX10hALpFpZMEkfTHNzNAufekxrxRTQ5snhADtOMllr6JRM1nrrr8Yd0vYu0LCW2ksCUKu%2BLWlecW4ANsl7RGpBl5xnDsFLtFW0I2A4e7BYiGtWlxhUWbvMhgW5hyL66IaNZU%2BYG%2BPzcffn3mOVNINKBY5%2F0TxNbK2X%2Ba8JiUtXM8CyBU2ExMXSLuMYRQNizsrd4ufWKuQaUqPYM28nedc2jcuWfH84OW9cq%2FFopv0JUfX5trJUx0Hi2ob8c5kDOcLLmf44G3Sc9tcYcKzn7qjM%3D',
    'JWTUser': '%7B%22account%22%3A%223220104373%22%2C%22id%22%3A636426%2C%22tenant_id%22%3A112%7D',
    # 'SESSIONZGQzMmEwOTktZTI1My00MDBiLTkxMDAtOTU0YjEyMWY4NzM3'  # SESSION已在上面填写，无需重复
})

resp = s.get(
    'https://sztz.zju.edu.cn/dekt/login/getLoginUrl',
    params={'returnUrl': 'https://sztz.zju.edu.cn/dekt/'},
    timeout=8
)
print('status', resp.status_code)
print('body', resp.text)    # 如果是 JSON，做 resp.json()
data = resp.json()
print('login url candidate:', data)  # 具体字段看返回结构
