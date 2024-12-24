package xyz.nosig.celechron

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.*
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.layout.*
import androidx.glance.preview.ExperimentalGlancePreviewApi
import androidx.glance.preview.Preview
import androidx.glance.text.FontFamily
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import com.it_nomads.fluttersecurestorage.FlutterSecureStorage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.*
import kotlinx.serialization.json.*
import java.net.HttpURLConnection
import java.net.URL
import java.time.LocalTime
import java.time.format.DateTimeFormatter

class ECardWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = ECardWidget()
}

class ECardWidget : GlanceAppWidget() {

    override suspend fun provideGlance(context: Context, id: GlanceId) {

        var balance: Int
        try {
            val storage = FlutterSecureStorage(context, HashMap())
            val values = storage.readAll()
            balance = fetchBalance(values["synjonesAuth"])
        } catch (e: Exception) {
            balance = -1
        }

        provideContent {
            GlanceTheme {
                content(context, id, balance)
            }
        }
    }

    @Composable
    private fun content(context: Context?, id: GlanceId?, balance: Int) {
        Column(
            modifier = GlanceModifier.background(GlanceTheme.colors.background).fillMaxSize().padding(horizontal = 16.dp, vertical = 12.dp).cornerRadius(16.dp).clickable{
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse("celechron://ecardpaypage"))
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context?.startActivity(intent)
            },
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(modifier = GlanceModifier.fillMaxWidth()) {
                Image(
                    provider = ImageProvider(
                        resId = R.drawable.credit_card_24px
                    ),
                    contentDescription = "Credit Card Icon",
                    modifier = GlanceModifier.size(20.dp),
                    colorFilter = ColorFilter.tint(GlanceTheme.colors.onBackground)
                )
                Spacer(modifier = GlanceModifier.width(4.dp))
                Text(
                    text = "校园卡余额", maxLines = 1, style = TextStyle(
                        color = GlanceTheme.colors.onBackground,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold
                    )
                )
                Spacer(modifier = GlanceModifier.defaultWeight())
                Image(
                    provider = ImageProvider(
                        resId = R.drawable.sync_24px
                    ),
                    contentDescription = "Sync Icon",
                    modifier = GlanceModifier.size(20.dp).clickable {
                        CoroutineScope(Dispatchers.Main).launch {
                            update(context!!, id!!)
                        }
                    },
                    colorFilter = ColorFilter.tint(GlanceTheme.colors.onBackground)
                )
            }

            Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.Bottom) {
                Column {
                    Text(
                        text = formatBalance(balance),
                        maxLines = 1,
                        style = TextStyle(
                            color = GlanceTheme.colors.primary,
                            fontSize = 28.sp,
                            fontWeight = FontWeight.Bold,
                            fontFamily = FontFamily.SansSerif
                        )
                    )
                    Text(
                        text = "更新时间：${LocalTime.now().format(DateTimeFormatter.ofPattern("HH:mm"))}",
                        maxLines = 1,
                        style = TextStyle(
                            color = GlanceTheme.colors.onBackground,
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold,
                        )
                    )

                }
                Spacer(modifier = GlanceModifier.defaultWeight())
                Column(horizontalAlignment = Alignment.End) {
                    Image(
                        provider = ImageProvider(
                            resId = R.drawable.qr_code_24px
                        ),
                        contentDescription = "QR Code Icon",
                        modifier = GlanceModifier.size(32.dp),
                        colorFilter = ColorFilter.tint(GlanceTheme.colors.primary)
                    )
                }
            }
        }
    }

    // If debugging the AppWidget, you can use the following preview
    // composable to see how the AppWidget will look like.
    @OptIn(ExperimentalGlancePreviewApi::class)
    @Preview(widthDp = 180, heightDp = 102)
    @Composable
    fun preview() {
        content(null, null, 1897)
    }

    private fun formatBalance(balance: Int): String {
        // Variable balance is 100 times larger than the actual value
        // For example, if the actual balance is ¥18.97, then variable balance is 18.97 * 100 = 1897
        // If variable balance is less than 10000, display it directly. For example, 1897 -> ¥ 18.97
        // If variable balance is greater than 10000, clip to 4 significant figures. For example, 18973 -> ¥ 189.7
        return if (balance < 0) {
            "待刷新"
        } else if (balance < 10000) {
            // Remember to pad zero before the decimal point
            "¥ ${balance / 100}.${balance % 100 / 10}${balance % 10}"
        } else {
            // Clip to 4 significant figures
            "¥ ${balance / 100}.${balance % 100 / 10}"
        }
    }

    private fun fetchBalance(synjonesAuth: String?): Int = runBlocking {
        val url = URL("https://ecard.zju.edu.cn/berserker-app/ykt/tsm/getCampusCards")
        async(Dispatchers.IO) {
            with(url.openConnection() as HttpURLConnection) {
                requestMethod = "GET"
                setRequestProperty("Synjones-Auth", "Bearer $synjonesAuth")
                setRequestProperty(
                    "User-Agent",
                    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36 Edg/126.0.0.0"
                )
                // Parse JSON response. response["data"]["card"][0]["db_balance"]
                val response = inputStream.bufferedReader().readText()
                val json = Json.parseToJsonElement(response)
                return@async json.jsonObject["data"]!!.jsonObject["card"]!!.jsonArray[0].jsonObject["db_balance"]!!.jsonPrimitive.int
            }
        }.await()
    }
}